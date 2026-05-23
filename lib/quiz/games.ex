defmodule Quiz.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Quiz.Repo

  alias Quiz.Games.Game
  alias Quiz.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any game changes.

  The broadcasted messages match the pattern:

    * {:created, %Game{}}
    * {:updated, %Game{}}
    * {:deleted, %Game{}}

  """
  def subscribe_games(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Quiz.PubSub, "user:#{key}:games")
  end

  defp broadcast_game(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Quiz.PubSub, "user:#{key}:games", message)
  end

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games(scope)
      [%Game{}, ...]

  """
  def list_games(%Scope{} = scope) do
    Repo.all_by(Game, user_id: scope.user.id)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(scope, 123)
      %Game{}

      iex> get_game!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(%Scope{} = scope, id) do
    Repo.get_by!(Game, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(scope, %{field: value})
      {:ok, %Game{}}

      iex> create_game(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(%Scope{} = scope, attrs) do
    with {:ok, game = %Game{}} <-
           %Game{}
           |> Game.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_game(scope, {:created, game})
      {:ok, game}
    end
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(scope, game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(scope, game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Scope{} = scope, %Game{} = game, attrs) do
    true = game.user_id == scope.user.id

    with {:ok, game = %Game{}} <-
           game
           |> Game.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_game(scope, {:updated, game})
      {:ok, game}
    end
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(scope, game)
      {:ok, %Game{}}

      iex> delete_game(scope, game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Scope{} = scope, %Game{} = game) do
    true = game.user_id == scope.user.id

    with {:ok, game = %Game{}} <-
           Repo.delete(game) do
      broadcast_game(scope, {:deleted, game})
      {:ok, game}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(scope, game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Scope{} = scope, %Game{} = game, attrs \\ %{}) do
    true = game.user_id == scope.user.id

    Game.changeset(game, attrs, scope)
  end

  alias Quiz.Games.Question
  alias Quiz.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any question changes.

  The broadcasted messages match the pattern:

    * {:created, %Question{}}
    * {:updated, %Question{}}
    * {:deleted, %Question{}}

  """
  def subscribe_questions(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Quiz.PubSub, "user:#{key}:questions")
  end

  defp broadcast_question(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Quiz.PubSub, "user:#{key}:questions", message)
  end

  @doc """
  Returns the list of questions.

  ## Examples

      iex> list_questions(scope)
      [%Question{}, ...]

  """
  def list_questions(%Scope{} = scope) do
    Repo.all_by(Question, user_id: scope.user.id)
  end

  @doc """
  Returns the list of questions belonging to the given game, ordered by position.
  """
  def list_questions_for_game(%Scope{} = scope, %Game{} = game) do
    true = game.user_id == scope.user.id

    Question
    |> where([q], q.user_id == ^scope.user.id and q.game_id == ^game.id)
    |> order_by([q], asc: q.position)
    |> Repo.all()
  end

  @doc """
  Gets a single question.

  Raises `Ecto.NoResultsError` if the Question does not exist.

  ## Examples

      iex> get_question!(scope, 123)
      %Question{}

      iex> get_question!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_question!(%Scope{} = scope, id) do
    Repo.get_by!(Question, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a question.

  ## Examples

      iex> create_question(scope, %{field: value})
      {:ok, %Question{}}

      iex> create_question(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_question(%Scope{} = scope, attrs) do
    with {:ok, question = %Question{}} <-
           %Question{}
           |> Question.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_question(scope, {:created, question})
      {:ok, question}
    end
  end

  @doc """
  Updates a question.

  ## Examples

      iex> update_question(scope, question, %{field: new_value})
      {:ok, %Question{}}

      iex> update_question(scope, question, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_question(%Scope{} = scope, %Question{} = question, attrs) do
    true = question.user_id == scope.user.id

    with {:ok, question = %Question{}} <-
           question
           |> Question.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_question(scope, {:updated, question})
      {:ok, question}
    end
  end

  @doc """
  Deletes a question.

  ## Examples

      iex> delete_question(scope, question)
      {:ok, %Question{}}

      iex> delete_question(scope, question)
      {:error, %Ecto.Changeset{}}

  """
  def delete_question(%Scope{} = scope, %Question{} = question) do
    true = question.user_id == scope.user.id

    with {:ok, question = %Question{}} <-
           Repo.delete(question) do
      broadcast_question(scope, {:deleted, question})
      {:ok, question}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking question changes.

  ## Examples

      iex> change_question(scope, question)
      %Ecto.Changeset{data: %Question{}}

  """
  def change_question(%Scope{} = scope, %Question{} = question, attrs \\ %{}) do
    true = question.user_id == scope.user.id

    Question.changeset(question, attrs, scope)
  end

  @doc """
  Rewrites the `:position` of each question in `ordered_ids` so that positions
  match the given order (1-based). All ids must belong to the given game and
  the scope's user, otherwise the function returns `{:error, :invalid}` and no
  changes are persisted.
  """
  def reposition_questions(%Scope{} = scope, %Game{} = game, ordered_ids)
      when is_list(ordered_ids) do
    true = game.user_id == scope.user.id

    questions =
      Question
      |> where([q], q.game_id == ^game.id and q.user_id == ^scope.user.id)
      |> Repo.all()

    existing_ids = MapSet.new(questions, & &1.id)
    given_ids = Enum.map(ordered_ids, &normalize_id/1)

    cond do
      Enum.any?(given_ids, &is_nil/1) ->
        {:error, :invalid}

      MapSet.new(given_ids) != existing_ids ->
        {:error, :invalid}

      length(given_ids) != length(Enum.uniq(given_ids)) ->
        {:error, :invalid}

      true ->
        multi =
          given_ids
          |> Enum.with_index(1)
          |> Enum.reduce(Ecto.Multi.new(), fn {id, pos}, multi ->
            Ecto.Multi.update_all(
              multi,
              {:pos, id},
              from(q in Question, where: q.id == ^id),
              set: [position: pos]
            )
          end)

        case Repo.transaction(multi) do
          {:ok, _} ->
            broadcast_question(scope, {:reordered, game})
            :ok

          {:error, _, _, _} ->
            {:error, :invalid}
        end
    end
  end

  defp normalize_id(id) when is_integer(id), do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp normalize_id(_), do: nil
end
