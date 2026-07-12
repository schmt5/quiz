defmodule Mix.Tasks.Quiz.Load do
  @shortdoc "In-VM load test: simulate N participants joining + answering a run"

  @moduledoc """
  Thin Mix wrapper around `Quiz.LoadTest` — see that module for what the test
  covers (and what it doesn't). Kept Mix-free there so the same test can run
  inside the production release via `bin/quiz eval`.

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
  `fly ssh console` → `/app/bin/quiz eval 'Quiz.LoadTest.run(...)'`), not just
  your laptop's Postgres. See `docs/scaling-for-event.md`.
  """

  use Mix.Task

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
    # Compile + boot the app; Quiz.LoadTest's own ensure_all_started is then a
    # no-op. `serve_endpoints` is false under Mix unless phx.server set it.
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    Quiz.LoadTest.run(opts)
  end
end
