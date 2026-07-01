defmodule Mix.Tasks.Quiz.Load do
  @shortdoc "In-VM load test: simulate N participants joining + answering a run"

  @moduledoc """
  Drives the `Quiz.Play` context directly (no browser, no WebSocket) to stress the
  parts of the app that break first under a big live run: the DB connection pool,
  answer upserts, the per-answer host COUNT, and the PubSub fan-out.

  It creates a throwaway user + game + questions, enrolls N participants, then runs
  the quiz — every participant submits an answer to each question — while measuring
  latency, errors and DB-pool queue time. Watch `/dashboard` (LiveDashboard) at the
  same time to see the pool and memory live.

  What this covers and what it doesn't: it exercises everything *below* the
  WebSocket line (Play context, Ecto/DB pool, Postgres, Phoenix.PubSub). It does
  NOT exercise the WebSocket transport or LiveView diffing — for that you'd add a
  browser swarm. See `docs/scaling-for-event.md`.

  ## Usage

      mix quiz.load
      mix quiz.load --participants 300 --questions 5 --mode herd
      mix quiz.load --participants 300 --mode jitter --spread 3000 --subscribers
      mix quiz.load --participants 300 --no-cleanup   # leave the game in the DB

  ## Options

    * `--participants` (int, default 300) — teams to simulate.
    * `--questions`    (int, default 5)   — single-choice questions in the game.
    * `--mode`         (`herd`|`jitter`, default `herd`) — `herd` fires all
      submissions for a question at once (worst case for the pool); `jitter`
      spreads them over `--spread` ms (realistic — humans read first).
    * `--spread`       (int ms, default 3000) — jitter window, `jitter` mode only.
    * `--subscribers`  (flag, default off) — spawn one process per participant that
      subscribes to the run topic and drains broadcasts, reproducing the real
      fan-out message load (~participants² messages/question).
    * `--think`        (int ms, default 300) — host pause between questions.
    * `--[no-]cleanup` (default cleanup on) — delete the throwaway game (cascades to
      participants/answers/questions) and user when done.

  Run against a prod-like target for real numbers (e.g. on the Fly machine via
  `fly ssh console` → `/app/bin/quiz eval`), not just your laptop's Postgres.
  """

  use Mix.Task

  alias Quiz.{Accounts, Games, Play, Repo}
  alias Quiz.Accounts.Scope

  @switches [
    participants: :integer,
    questions: :integer,
    mode: :string,
    spread: :integer,
    think: :integer,
    subscribers: :boolean,
    cleanup: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    # Boot the app (Repo, PubSub, Endpoint) but not the web server we don't need.
    Application.put_env(:phoenix, :serve_endpoints, false)
    Mix.Task.run("app.start")

    # Silence Ecto's per-query debug logging — at 300×N it floods stdout and adds
    # real overhead that would skew the measurement.
    Logger.configure(level: :warning)

    {opts, _, _} = OptionParser.parse(argv, switches: @switches)

    cfg = %{
      participants: opts[:participants] || 300,
      questions: opts[:questions] || 5,
      mode: parse_mode(opts[:mode]),
      spread: opts[:spread] || 3000,
      think: opts[:think] || 300,
      subscribers: opts[:subscribers] || false,
      cleanup: Keyword.get(opts, :cleanup, true)
    }

    pool_size = Application.get_env(:quiz, Repo)[:pool_size]

    banner(cfg, pool_size)

    metrics = attach_pool_telemetry()
    {user, scope, game, _questions} = build_fixture(scope_or_raise(), cfg)

    subs = if cfg.subscribers, do: start_subscribers(game, cfg.participants), else: []

    try do
      # --- JOIN phase: everyone enrolls -------------------------------------
      {join_us, participants} = timed(fn -> join_all(game, cfg) end)
      report_phase("JOIN", join_us, participants)

      # --- RUN: start, then per-question answer bursts + advance ------------
      {:ok, game} = Play.start_run(scope, game)

      Enum.reduce(1..cfg.questions, game, fn i, game ->
        question = Play.current_question(game)

        {ans_us, results} =
          timed(fn -> submit_all(game, question, ok_participants(participants), cfg) end)

        report_phase("Q#{i}/#{cfg.questions} answers", ans_us, results)

        Process.sleep(cfg.think)
        {:ok, game} = Play.advance_run(scope, game)
        game
      end)
      |> then(fn game -> Play.publish_grading(scope, game) end)

      report_pool(metrics)
      report_subscribers(subs)
    after
      Enum.each(subs, &send(&1, :stop))
      detach_pool_telemetry()
      if cfg.cleanup, do: cleanup(user, game), else: keep_notice(game)
    end
  end

  ## Fixture -----------------------------------------------------------------

  defp build_fixture(scope, cfg) do
    user = scope.user

    {:ok, game} =
      Games.create_game(scope, %{title: "LOAD TEST #{System.unique_integer([:positive])}"})

    questions =
      Enum.map(1..cfg.questions, fn pos ->
        {:ok, q} =
          Games.create_question(scope, %{
            game_id: game.id,
            type: :single_choice,
            prompt: "Load question #{pos}",
            position: pos,
            data: %{choices: [%{text: "A", correct: true}, %{text: "B", correct: false}]}
          })

        q
      end)

    # Open for enrollment (draft -> open); enroll/2 requires :open or :running.
    {:ok, game} = Play.open_run(scope, game)
    {user, scope, game, questions}
  end

  defp scope_or_raise do
    {:ok, user} =
      Accounts.register_user(%{
        name: "Load Tester",
        email: "loadtest-#{System.unique_integer([:positive])}@example.com",
        password: "load test password!"
      })

    Scope.for_user(user)
  end

  ## Phases ------------------------------------------------------------------

  defp join_all(game, cfg) do
    1..cfg.participants
    |> Task.async_stream(
      fn i ->
        case Play.enroll(game, "Team #{i}") do
          {:ok, participant, _token} -> {:ok, participant}
          {:error, reason} -> {:error, reason}
        end
      end,
      max_concurrency: cfg.participants,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  defp submit_all(game, question, participants, cfg) do
    participants
    |> Task.async_stream(
      fn participant ->
        if cfg.mode == :jitter, do: Process.sleep(:rand.uniform(cfg.spread))

        # "0" grades full (choice A is correct), "1" grades zero — mix both so
        # the leaderboard has a real spread.
        answer = Enum.random(["0", "1"])

        {us, result} =
          timed_us(fn -> Play.submit_answer(game, participant, question, %{"answer" => answer}) end)

        case result do
          {:ok, _} -> {:ok, us}
          {:error, reason} -> {:error, reason}
        end
      end,
      max_concurrency: cfg.participants,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, res} -> res end)
  end

  defp ok_participants(results) do
    for {:ok, p} <- results, do: p
  end

  ## Subscribers (simulate LiveView processes receiving the fan-out) ----------

  defp start_subscribers(game, count) do
    parent = self()

    subs =
      for _ <- 1..count do
        spawn(fn ->
          Play.subscribe(game)
          send(parent, :subscribed)
          subscriber_loop(0)
        end)
      end

    # Wait until all subscriptions are live so they catch the join broadcasts.
    Enum.each(subs, fn _ -> receive do: (:subscribed -> :ok) end)
    subs
  end

  defp subscriber_loop(count) do
    receive do
      {:report, from} -> send(from, {:count, count})
      :stop -> :ok
      _msg -> subscriber_loop(count + 1)
    end
  end

  ## Metrics -----------------------------------------------------------------

  # Slots: 1 = query count, 2 = summed queue_time (ns), 3 = max queue_time (ns),
  # 4 = count of queries that queued longer than queue_target (50ms).
  @queue_target_ns 50_000_000

  defp attach_pool_telemetry do
    ref = :atomics.new(4, [])
    handler = {__MODULE__, System.unique_integer([:positive])}

    :telemetry.attach(
      handler,
      [:quiz, :repo, :query],
      &__MODULE__.handle_query_event/4,
      ref
    )

    Process.put(:quiz_load_handler, handler)
    ref
  end

  defp detach_pool_telemetry do
    case Process.get(:quiz_load_handler) do
      nil -> :ok
      handler -> :telemetry.detach(handler)
    end
  end

  @doc false
  # Public because :telemetry needs a remote (M,F,A) callback, not a closure.
  def handle_query_event(_event, measurements, _meta, ref) do
    queue = measurements[:queue_time] || 0
    :atomics.add(ref, 1, 1)
    :atomics.add(ref, 2, queue)
    atomic_max(ref, 3, queue)
    if queue > @queue_target_ns, do: :atomics.add(ref, 4, 1)
  end

  defp atomic_max(ref, i, val) do
    cur = :atomics.get(ref, i)

    if val > cur do
      case :atomics.compare_exchange(ref, i, cur, val) do
        :ok -> :ok
        _stale -> atomic_max(ref, i, val)
      end
    end
  end

  ## Reporting ---------------------------------------------------------------

  defp banner(cfg, pool_size) do
    info("""

    ── quiz.load ──────────────────────────────────────────────
      participants : #{cfg.participants}
      questions    : #{cfg.questions}
      mode         : #{cfg.mode}#{if cfg.mode == :jitter, do: " (spread #{cfg.spread}ms)", else: ""}
      subscribers  : #{cfg.subscribers}
      DB pool_size : #{pool_size}
      env          : #{Mix.env()}
    ───────────────────────────────────────────────────────────
    """)
  end

  defp report_phase(label, wall_us, results) do
    ok_count = Enum.count(results, &match?({:ok, _}, &1))
    err_count = length(results) - ok_count

    # Only answer submissions carry a latency ({:ok, microseconds}); JOIN results
    # are {:ok, %Participant{}}, so is_integer filters them out.
    lat = for {:ok, us} <- results, is_integer(us), do: us

    latency_line =
      case lat do
        [] -> ""
        _ -> "  |  latency p50 #{ms(percentile(lat, 50))} / p95 #{ms(percentile(lat, 95))} / max #{ms(Enum.max(lat))}"
      end

    info("  #{pad(label)}  #{ms(wall_us)} wall  |  #{ok_count} ok / #{err_count} err#{latency_line}")

    if err_count > 0, do: info("     ⚠ first errors: #{inspect(first_errors(results))}")
  end

  defp first_errors(results) do
    results
    |> Enum.filter(&match?({:error, _}, &1))
    |> Enum.take(3)
  end

  defp report_pool(ref) do
    count = :atomics.get(ref, 1)
    sum = :atomics.get(ref, 2)
    max = :atomics.get(ref, 3)
    over = :atomics.get(ref, 4)
    avg = if count > 0, do: div(sum, count), else: 0

    info("""

    ── DB pool (Ecto queue_time = time waiting for a free connection) ──
      queries run          : #{count}
      avg queue wait       : #{ns_ms(avg)}
      max queue wait       : #{ns_ms(max)}
      queries over 50ms    : #{over}#{if over > 0, do: "   ⚠ pool saturating — raise POOL_SIZE", else: ""}
    ───────────────────────────────────────────────────────────
    """)
  end

  defp report_subscribers([]), do: :ok

  defp report_subscribers(subs) do
    parent = self()
    Enum.each(subs, &send(&1, {:report, parent}))

    total =
      Enum.reduce(subs, 0, fn _sub, acc ->
        receive do
          {:count, n} -> acc + n
        after
          5000 -> acc
        end
      end)

    info("  subscribers received #{total} broadcast messages total (fan-out volume)")
  end

  ## Cleanup -----------------------------------------------------------------

  defp cleanup(user, game) do
    # game delete cascades participants -> answers, and questions -> corrections.
    Repo.delete(game)
    Repo.delete(user)
    info("\n✔ cleaned up throwaway game + user")
  end

  defp keep_notice(game) do
    info("\n↺ left game in DB (join_code #{game.join_code}) — delete it manually when done")
  end

  ## Helpers -----------------------------------------------------------------

  defp parse_mode("jitter"), do: :jitter
  defp parse_mode(_), do: :herd

  defp timed(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    {System.monotonic_time(:microsecond) - start, result}
  end

  defp timed_us(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    {System.monotonic_time(:microsecond) - start, result}
  end

  defp percentile([], _), do: 0

  defp percentile(list, p) do
    sorted = Enum.sort(list)
    idx = min(length(sorted) - 1, round(p / 100 * length(sorted)))
    Enum.at(sorted, idx)
  end

  defp ms(us) when is_integer(us), do: "#{Float.round(us / 1000, 1)}ms"
  defp ns_ms(ns) when is_integer(ns), do: "#{Float.round(ns / 1_000_000, 1)}ms"
  defp pad(s), do: String.pad_trailing(s, 18)
  defp info(msg), do: Mix.shell().info(msg)
end
