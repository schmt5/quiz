defmodule Quiz.Games.Question do
  use Ecto.Schema
  import Ecto.Changeset

  alias Quiz.Games.Question.Data

  schema "questions" do
    field :type, Ecto.Enum, values: [:single_choice, :text_input]
    field :prompt, :string
    field :position, :integer
    embeds_one :data, Data, on_replace: :update
    field :game_id, :id
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(question, attrs, user_scope) do
    changeset =
      question
      |> cast(attrs, [:type, :prompt, :position, :game_id])
      |> validate_required([:type, :prompt, :position, :game_id])
      |> maybe_reset_data_on_type_change()

    type = get_field(changeset, :type)

    changeset
    |> cast_embed(:data, with: &Data.changeset(&1, &2, type))
    |> put_change(:user_id, user_scope.user.id)
  end

  defp maybe_reset_data_on_type_change(changeset) do
    with {:ok, _new_type} <- fetch_change(changeset, :type),
         %Data{} <- get_field(changeset, :data) do
      # Clear the existing embed in-place; on_replace: :update requires a map
      # (not a struct). cast_embed afterwards will populate from the new attrs.
      put_embed(changeset, :data, %{choices: [], solutions: []})
    else
      _ -> changeset
    end
  end

  @doc """
  Checks a user's answer against a question.

  - `:text_input`: case-insensitive + whitespace-trimmed comparison against any
    configured solution.
  - `:single_choice`: the answer is the 0-based index of the chosen choice.
  """
  def correct_answer?(%__MODULE__{type: :text_input, data: %Data{solutions: solutions}}, input) do
    normalized = input |> to_string() |> String.trim() |> String.downcase()

    Enum.any?(solutions, fn %{text: text} ->
      String.downcase(String.trim(text || "")) == normalized
    end)
  end

  def correct_answer?(%__MODULE__{type: :single_choice, data: %Data{choices: choices}}, index)
      when is_integer(index) do
    case Enum.at(choices, index) do
      %{correct: true} -> true
      _ -> false
    end
  end

  def correct_answer?(_question, _input), do: false
end
