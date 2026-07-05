defmodule Quiz.Play do
  @moduledoc """
  The Play context: running a quiz (a "Durchführung").

  Authoring lives in `Quiz.Games`. This context owns the *runtime* concerns of a
  single, inline run on a `Game`: opening/starting the run, participant
  enrollment, reconnect via a signed token, and the real-time fan-out.

  Operator actions (`open_run/2`, `start_run/2`) are scope-checked against the
  game owner. Participant actions (`get_game_by_join_code/1`, `enroll/2`,
  `restore_participant/2`) are intentionally *unscoped* — participants have no
  account and are authorized purely by the join code and their signed token.

  All real-time messages for a run are broadcast on the single topic
  `"game:\#{game.id}"`:

    * `{:participant_joined, %Participant{}}`
    * `{:status_changed, %Game{}}`
    * `{:answer_submitted, position}`

  """

  import Ecto.Query, warn: false

  alias Quiz.Repo
  alias Quiz.Games
  alias Quiz.Games.{Game, Question}
  alias Quiz.Play.{Participant, Answer, Correction}
  alias Quiz.Accounts.Scope

  @token_salt "participant"
  # Participants may reconnect within this window (seconds). One day comfortably
  # covers any single sitting of a quiz.
  @token_max_age 86_400

  # Statuses during which new participants may still enroll.
  @joinable [:open, :running]

  ## Real-time -------------------------------------------------------------

  @doc "Subscribes the caller to the run's real-time topic."
  def subscribe(%Game{} = game) do
    Phoenix.PubSub.subscribe(Quiz.PubSub, topic(game))
  end

  defp broadcast(%Game{} = game, message) do
    Phoenix.PubSub.broadcast(Quiz.PubSub, topic(game), message)
  end

  defp topic(%Game{id: id}), do: "game:#{id}"

  ## Operator actions (scoped) ---------------------------------------------

  @doc """
  Opens a run for enrollment (`:draft`/`:closed` -> `:open`). Operator only.

  This is the *publish gate*: before the quiz becomes joinable, every question
  must meet the playable bar (`Quiz.Games.Question.ready?/1`). If any are still
  incomplete the transition is refused with `{:error, {:incomplete_questions,
  questions}}` so the caller can point the author at what to finish. A quiz with
  no questions at all still opens (an empty lobby); `start_run/2` guards that.
  """
  def open_run(%Scope{} = scope, %Game{} = game) do
    case Games.incomplete_questions(scope, game) do
      [] -> transition(scope, game, %{status: :open})
      incomplete -> {:error, {:incomplete_questions, incomplete}}
    end
  end

  @doc """
  Starts the quiz (`:open` -> `:running`) and parks everyone on the first
  question. Rejects a quiz that has no questions.
  """
  def start_run(%Scope{} = scope, %Game{} = game) do
    case first_position(scope, game) do
      nil ->
        {:error, :no_questions}

      position ->
        transition(scope, game, %{status: :running, current_position: position, revealing: false})
    end
  end

  @doc """
  Reveals the current question's solution/stats (`per_question` review mode): the
  run stays `:running` on the same `current_position`, but `revealing` flips to
  true so the host screen shows the solution and `submit_answer/4` stops accepting
  answers. Operator only.
  """
  def reveal_run(%Scope{} = scope, %Game{} = game) do
    transition(scope, game, %{status: :running, revealing: true})
  end

  @doc """
  Advances the run to the next question (`running` stays, `current_position`
  bumps to the next question's position). When already on the last question,
  finishes the run (`:running` -> `:finished`). Always clears `revealing` so a
  bumped/finished game never carries a stale reveal. Operator only.
  """
  def advance_run(%Scope{} = scope, %Game{current_position: position} = game) do
    case next_position(game, position) do
      nil -> transition(scope, game, %{status: :finished, revealing: false})
      next -> transition(scope, game, %{current_position: next, revealing: false})
    end
  end

  @doc """
  Moves the run back to the previous question (`running` stays, `current_position`
  drops to the previous question's position). No-op on the first question. Always
  clears `revealing` so a re-opened question collects answers again — the team is
  sent back to see (and re-enter) what they submitted. Operator only.
  """
  def retreat_run(%Scope{} = scope, %Game{current_position: position} = game) do
    case prev_position(game, position) do
      nil -> {:ok, game}
      prev -> transition(scope, game, %{current_position: prev, revealing: false})
    end
  end

  defp next_position(%Game{}, nil), do: nil

  defp next_position(%Game{id: game_id}, position) do
    Question
    |> where([q], q.game_id == ^game_id and q.position > ^position)
    |> order_by([q], asc: q.position)
    |> limit(1)
    |> select([q], q.position)
    |> Repo.one()
  end

  defp prev_position(%Game{}, nil), do: nil

  defp prev_position(%Game{id: game_id}, position) do
    Question
    |> where([q], q.game_id == ^game_id and q.position < ^position)
    |> order_by([q], desc: q.position)
    |> limit(1)
    |> select([q], q.position)
    |> Repo.one()
  end

  defp transition(%Scope{} = scope, %Game{} = game, attrs) do
    true = game.user_id == scope.user.id

    with {:ok, game} <-
           game
           |> Game.transition_changeset(attrs)
           |> Repo.update() do
      broadcast(game, {:status_changed, game})
      {:ok, game}
    end
  end

  defp first_position(%Scope{} = scope, %Game{} = game) do
    case Games.list_questions_for_game(scope, game) do
      [] -> nil
      questions -> questions |> Enum.map(& &1.position) |> Enum.min()
    end
  end

  ## Participant actions (unscoped) ----------------------------------------

  @doc """
  Looks up a joinable game by its (case-insensitive) join code.

  Distinguishes *why* a code can't be joined so the UI can say something useful
  instead of a blanket "wrong PIN":

    * `{:ok, game}` — the run accepts enrollment (`:open`/`:running`).
    * `{:error, :not_started}` — the code is valid but its quiz is still a
      `:draft` (the operator hasn't opened it yet).
    * `{:error, :ended}` — the code is valid but its quiz has `:finished`/`:closed`.
    * `{:error, :not_found}` — no quiz has this code.
  """
  def get_game_by_join_code(code) when is_binary(code) do
    normalized = code |> String.trim() |> String.upcase()

    case Repo.get_by(Game, join_code: normalized) do
      %Game{status: status} = game when status in @joinable -> {:ok, game}
      %Game{status: :draft} -> {:error, :not_started}
      %Game{} -> {:error, :ended}
      nil -> {:error, :not_found}
    end
  end

  def get_game_by_join_code(_), do: {:error, :not_found}

  @doc """
  Looks up a game for the *play* view by its (case-insensitive) join code.

  Unlike `get_game_by_join_code/1`, this also resolves a game whose run has
  already finished (`:finished`/`:closed`), so a team that reloads or reconnects
  after the quiz ends still lands on the finished screen (and the published
  leaderboard) rather than being bounced back to the join page. Only a `:draft`
  game — which has no run yet — returns `{:error, :not_found}`.
  """
  def get_game_for_play(code) when is_binary(code) do
    normalized = code |> String.trim() |> String.upcase()

    case Repo.get_by(Game, join_code: normalized) do
      %Game{status: status} = game when status != :draft -> {:ok, game}
      _ -> {:error, :not_found}
    end
  end

  def get_game_for_play(_), do: {:error, :not_found}

  @doc "Returns a changeset for the enrollment form."
  def change_enrollment(attrs \\ %{}) do
    Participant.changeset(%Participant{}, attrs)
  end

  @doc """
  Enrolls a *new* team into the run. Returns `{:ok, participant, token}` where
  `token` is a signed handle the client stores to reconnect later.

  Names are strictly first come, first serve: enrolling with a name that already
  exists in this game returns `{:error, :name_taken}`, whether or not that team
  is currently connected. The signed token in the browser's `localStorage` is
  the *only* way back into an existing team (`restore_participant/2`) — a team
  that loses it must join under a new name.
  """
  def enroll(%Game{status: status} = game, name) when status in @joinable do
    trimmed = name |> to_string() |> String.trim()

    case Repo.get_by(Participant, game_id: game.id, name: trimmed) do
      %Participant{} ->
        {:error, :name_taken}

      nil ->
        case %Participant{}
             |> Participant.changeset(%{name: name, game_id: game.id})
             |> Repo.insert() do
          {:ok, participant} ->
            broadcast(game, {:participant_joined, participant})
            {:ok, participant, sign_token(participant)}

          {:error, changeset} ->
            # Lost a race to a concurrent insert of the same name.
            case Repo.get_by(Participant, game_id: game.id, name: trimmed) do
              %Participant{} -> {:error, :name_taken}
              nil -> {:error, changeset}
            end
        end
    end
  end

  def enroll(%Game{}, _name), do: {:error, :not_joinable}

  @doc """
  Rebinds a returning participant from their signed token, asserting it belongs
  to the given game.
  """
  def restore_participant(%Game{} = game, token) when is_binary(token) do
    with {:ok, id} <-
           Phoenix.Token.verify(QuizWeb.Endpoint, @token_salt, token, max_age: @token_max_age),
         %Participant{game_id: game_id} = participant <- Repo.get(Participant, id),
         true <- game_id == game.id do
      {:ok, participant}
    else
      _ -> {:error, :invalid}
    end
  end

  def restore_participant(%Game{}, _token), do: {:error, :invalid}

  @doc "Lists all enrolled participants for a game, oldest first."
  def list_participants(%Game{} = game) do
    Participant
    |> where([p], p.game_id == ^game.id)
    |> order_by([p], asc: p.inserted_at, asc: p.id)
    |> Repo.all()
  end

  defp sign_token(%Participant{id: id}) do
    Phoenix.Token.sign(QuizWeb.Endpoint, @token_salt, id)
  end

  ## Answers ---------------------------------------------------------------

  @doc """
  Records a team's answer to a question (latest wins). The raw form params are
  normalized to the canonical shape `Question.correct_answer?/2` expects, scored,
  and upserted. Broadcasts `{:answer_submitted, question.position}`.

  Rejects with `{:error, :not_accepting_answers}` once the host has revealed the
  question (`per_question` review mode) — a server-side guard, since a reconnecting
  client can race the broadcast that locks its form, and a late submission would
  corrupt the stats the room is discussing.
  """
  def submit_answer(%Game{revealing: true}, %Participant{}, %Question{}, _params) do
    {:error, :not_accepting_answers}
  end

  def submit_answer(%Game{} = game, %Participant{} = participant, %Question{} = question, params) do
    canonical = canonicalize(question, params)
    grade = auto_grade(question, canonical)

    attrs = %{
      payload: %{"value" => canonical},
      grade: grade,
      participant_id: participant.id,
      question_id: question.id
    }

    with {:ok, answer} <-
           %Answer{}
           |> Answer.changeset(attrs)
           |> Repo.insert(
             on_conflict: {:replace, [:payload, :grade, :updated_at]},
             conflict_target: [:participant_id, :question_id]
           ) do
      broadcast(game, {:answer_submitted, question.position})
      {:ok, answer}
    end
  end

  @doc """
  The automatic verdict for an answer: `:matching` earns `:half` for a partial
  match, otherwise `:full`/`:zero` from `Question.correct_answer?/2`.
  """
  def auto_grade(%Question{type: :matching} = question, canonical) do
    case Question.score_answer(question, canonical) do
      {n, total} when total > 0 and n == total -> :full
      {n, _total} when n > 0 -> :half
      _ -> :zero
    end
  end

  def auto_grade(%Question{} = question, canonical) do
    if Question.correct_answer?(question, canonical), do: :full, else: :zero
  end

  @doc "Returns this team's stored answer for a question, or `nil`."
  def get_answer(%Participant{id: pid}, %Question{id: qid}) do
    Repo.get_by(Answer, participant_id: pid, question_id: qid)
  end

  @doc "Counts how many teams have answered the question at `position`."
  def count_answers(%Game{id: game_id}, position) when is_integer(position) do
    Answer
    |> join(:inner, [a], q in Question, on: q.id == a.question_id)
    |> where([a, q], q.game_id == ^game_id and q.position == ^position)
    |> select([a], count(a.id))
    |> Repo.one()
  end

  def count_answers(%Game{}, _position), do: 0

  ## Correction ------------------------------------------------------------

  @doc "All answers for a question, each paired with its participant."
  def list_answers_for_question(%Question{id: qid}) do
    Answer
    |> join(:inner, [a], p in Participant, on: p.id == a.participant_id)
    |> where([a], a.question_id == ^qid)
    |> order_by([a], asc: a.inserted_at)
    |> select([a, p], {a, p})
    |> Repo.all()
  end

  @doc """
  Buckets a question's answers for bulk correction: identical answers grouped,
  most common first, the "no answer" group last. Each group carries the shared
  `grade`, the `count`, the participant names, and the underlying `answer_ids`.
  Only `:text_input` is grouped; other types return `[]`.
  """
  def group_answers(%Question{type: :text_input} = question, pairs) do
    pairs
    |> Enum.group_by(fn {answer, _p} -> group_key(question, answer) end)
    |> Enum.map(fn {key, members} ->
      {answer, _p} = hd(members)

      %{
        key: key,
        label: group_label(question, key, answer),
        blank: key == :blank,
        grade: answer.grade,
        count: length(members),
        participants: Enum.map(members, fn {_a, p} -> p.name end),
        answer_ids: Enum.map(members, fn {a, _p} -> a.id end)
      }
    end)
    |> Enum.sort_by(fn g -> {(g.blank && 1) || 0, -g.count} end)
  end

  def group_answers(_question, _pairs), do: []

  defp group_key(%Question{type: :text_input}, %Answer{payload: %{"value" => value}}) do
    case normalize_text(value) do
      "" -> :blank
      norm -> norm
    end
  end

  defp group_label(_question, :blank, _answer), do: nil

  defp group_label(%Question{type: :text_input}, _key, %Answer{payload: %{"value" => value}}) do
    to_string(value)
  end

  defp normalize_text(value), do: value |> to_string() |> String.trim() |> String.downcase()

  @doc "Sets the grade for every answer in a group (the corrector judging once)."
  def grade_group(answer_ids, grade)
      when is_list(answer_ids) and grade in [:full, :half, :zero] do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Answer
      |> where([a], a.id in ^answer_ids)
      |> Repo.update_all(set: [grade: grade, updated_at: now])

    {:ok, count}
  end

  @doc """
  Marks a question's correction as finalised ("Fertig").
  """
  def mark_question_done(%Question{id: qid}) do
    %Correction{}
    |> Correction.changeset(%{question_id: qid, done: true})
    |> Repo.insert(on_conflict: {:replace, [:done, :updated_at]}, conflict_target: :question_id)
  end

  @doc "Whether a question's correction has been finalised."
  def correction_done?(%Question{id: qid}) do
    case Repo.get_by(Correction, question_id: qid) do
      %Correction{done: done} -> done
      _ -> false
    end
  end

  @doc """
  Per-question correction status for a game's overview: the question, its answer
  count, whether it is `done`, and whether it supports grouped grading.
  """
  def correction_overview(%Game{} = game) do
    questions =
      Question
      |> where([q], q.game_id == ^game.id)
      |> order_by([q], asc: q.position)
      |> Repo.all()

    counts =
      Answer
      |> join(:inner, [a], q in Question, on: q.id == a.question_id)
      |> where([_a, q], q.game_id == ^game.id)
      |> group_by([a], a.question_id)
      |> select([a], {a.question_id, count(a.id)})
      |> Repo.all()
      |> Map.new()

    done =
      Correction
      |> join(:inner, [c], q in Question, on: q.id == c.question_id)
      |> where([c, q], q.game_id == ^game.id and c.done == true)
      |> select([c], c.question_id)
      |> Repo.all()
      |> MapSet.new()

    Enum.map(questions, fn q ->
      %{
        question: q,
        answer_count: Map.get(counts, q.id, 0),
        done: MapSet.member?(done, q.id),
        gradable: q.type == :text_input
      }
    end)
  end

  @doc "Publishes the grading, revealing the leaderboard. Operator only."
  def publish_grading(%Scope{} = scope, %Game{} = game) do
    true = game.user_id == scope.user.id

    with {:ok, game} <-
           game |> Ecto.Changeset.change(grading_published: true) |> Repo.update() do
      broadcast(game, {:grading_published, game})
      {:ok, game}
    end
  end

  @doc """
  Final standings: each participant with their summed points (full = 1, half =
  0.5, zero = 0), ordered high to low, with tie-aware ranks.
  """
  def leaderboard(%Game{} = game) do
    scores =
      Answer
      |> join(:inner, [a], q in Question, on: q.id == a.question_id)
      |> where([_a, q], q.game_id == ^game.id)
      |> select([a], {a.participant_id, a.grade})
      |> Repo.all()
      |> Enum.group_by(fn {pid, _g} -> pid end, fn {_pid, g} -> g end)
      |> Map.new(fn {pid, grades} ->
        {pid, Enum.reduce(grades, 0.0, &(Answer.points(&1) + &2))}
      end)

    list_participants(game)
    |> Enum.map(fn p -> %{participant: p, score: Map.get(scores, p.id, 0.0)} end)
    |> Enum.sort_by(& &1.score, :desc)
    |> with_ranks()
  end

  defp with_ranks(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.map_reduce(nil, fn {row, idx}, prev ->
      rank =
        case prev do
          {score, rank} when score == row.score -> rank
          _ -> idx
        end

      {Map.put(row, :rank, rank), {row.score, rank}}
    end)
    |> elem(0)
  end

  # Turns the per-type form params into the canonical answer value.
  defp canonicalize(%Question{type: :text_input}, params) do
    to_string(params["answer"] || "")
  end

  defp canonicalize(%Question{type: :single_choice}, params) do
    case params["answer"] do
      v when is_binary(v) ->
        case Integer.parse(v) do
          {i, _} -> i
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp canonicalize(%Question{type: :sequence}, params) do
    (params["answer"] || "") |> String.split(",", trim: true)
  end

  defp canonicalize(%Question{type: :matching}, params) do
    with v when is_binary(v) and v != "" <- params["answer"],
         {:ok, map} when is_map(map) <- Jason.decode(v) do
      map
    else
      _ -> %{}
    end
  end

  defp canonicalize(%Question{type: :pin_on_image}, params) do
    ans = params["answer"] || %{}
    %{"x" => parse_float(ans["x"]), "y" => parse_float(ans["y"])}
  end

  defp canonicalize(_question, _params), do: nil

  defp parse_float(v) when is_number(v), do: v / 1

  defp parse_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_float(_), do: nil

  ## Questions -------------------------------------------------------------

  @doc """
  Returns the question a participant should currently see, based on the game's
  `current_position`. Returns `nil` when the run hasn't reached a question.
  """
  def current_question(%Game{current_position: nil}), do: nil

  def current_question(%Game{id: game_id, current_position: position}) do
    Question
    |> where([q], q.game_id == ^game_id and q.position == ^position)
    |> limit(1)
    |> Repo.one()
  end

  @doc "Fetches a game's question at a given position (for the corrector view)."
  def get_question(%Game{id: game_id}, position) when is_integer(position) do
    Question
    |> where([q], q.game_id == ^game_id and q.position == ^position)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns `{number, total}` for the current question: its 1-based ordinal among
  the game's ordered questions and the total count. Returns `{0, 0}` before a
  run reaches a question.
  """
  def question_numbering(%Game{current_position: nil}), do: {0, 0}

  def question_numbering(%Game{id: game_id, current_position: position}) do
    positions =
      Question
      |> where([q], q.game_id == ^game_id)
      |> order_by([q], asc: q.position)
      |> select([q], q.position)
      |> Repo.all()

    number =
      case Enum.find_index(positions, &(&1 == position)) do
        nil -> 0
        index -> index + 1
      end

    {number, length(positions)}
  end
end
