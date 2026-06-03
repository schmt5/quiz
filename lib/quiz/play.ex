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

  """

  import Ecto.Query, warn: false

  alias Quiz.Repo
  alias Quiz.Games
  alias Quiz.Games.{Game, Question}
  alias Quiz.Play.Participant
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
  """
  def open_run(%Scope{} = scope, %Game{} = game) do
    transition(scope, game, %{status: :open})
  end

  @doc """
  Starts the quiz (`:open` -> `:running`) and parks everyone on the first
  question. Rejects a quiz that has no questions.
  """
  def start_run(%Scope{} = scope, %Game{} = game) do
    case first_position(scope, game) do
      nil -> {:error, :no_questions}
      position -> transition(scope, game, %{status: :running, current_position: position})
    end
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

  Returns `{:ok, game}` only while the run accepts enrollment, otherwise
  `{:error, :not_found}`.
  """
  def get_game_by_join_code(code) when is_binary(code) do
    normalized = code |> String.trim() |> String.upcase()

    case Repo.get_by(Game, join_code: normalized) do
      %Game{status: status} = game when status in @joinable -> {:ok, game}
      _ -> {:error, :not_found}
    end
  end

  def get_game_by_join_code(_), do: {:error, :not_found}

  @doc "Returns a changeset for the enrollment form."
  def change_enrollment(attrs \\ %{}) do
    Participant.changeset(%Participant{}, attrs)
  end

  @doc """
  Enrolls a team into the run. Returns `{:ok, participant, token}` where `token`
  is a signed handle the client stores to reconnect later.
  """
  def enroll(%Game{status: status} = game, name) when status in @joinable do
    with {:ok, participant} <-
           %Participant{}
           |> Participant.changeset(%{name: name, game_id: game.id})
           |> Repo.insert() do
      broadcast(game, {:participant_joined, participant})
      {:ok, participant, sign_token(participant)}
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
