defmodule Quiz.Games.Question do
  use Ecto.Schema
  import Ecto.Changeset

  alias Quiz.Games.Question.{Data, Pair, Pin}

  schema "questions" do
    field :type, Ecto.Enum,
      values: [:single_choice, :text_input, :sequence, :pin_on_image, :matching]

    field :prompt, :string
    field :description, :string
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
      |> cast(attrs, [:type, :prompt, :description, :position, :game_id])
      |> validate_required([:type, :prompt, :position, :game_id])
      |> update_change(:description, &Quiz.HTML.sanitize_description/1)
      |> maybe_reset_data_on_type_change()

    type = get_field(changeset, :type)

    changeset
    |> cast_embed(:data, with: &Data.changeset(&1, &2, type))
    |> put_change(:user_id, user_scope.user.id)
  end

  @doc """
  Lenient changeset for the instant-create flow.

  Picking a type persists a skeleton question immediately, so `:prompt` and the
  type-specific `:data` are intentionally *not* required here — they are filled
  in and validated later through `changeset/3` in the edit form.
  """
  def create_changeset(question, attrs, user_scope) do
    question
    |> cast(attrs, [:type, :position, :game_id])
    |> validate_required([:type, :position, :game_id])
    |> put_change(:user_id, user_scope.user.id)
  end

  defp maybe_reset_data_on_type_change(changeset) do
    with {:ok, _new_type} <- fetch_change(changeset, :type),
         %Data{} <- get_field(changeset, :data) do
      # Clear the existing embed in-place; on_replace: :update requires a map
      # (not a struct). cast_embed afterwards will populate from the new attrs.
      put_embed(changeset, :data, %{choices: [], solutions: [], items: [], pairs: [], pin: nil})
    else
      _ -> changeset
    end
  end

  @doc """
  Checks a user's answer against a question.

  - `:text_input`: case-insensitive + whitespace-trimmed comparison against any
    configured solution.
  - `:single_choice`: the answer is the 0-based index of the chosen choice.
  - `:pin_on_image`: the answer is `%{"x" => float, "y" => float}` (normalized
    `0..1`); correct when it falls within the target's tolerance radius.
  - `:matching`: the answer is `%{pair_id => chosen_right_text}`; correct when
    every pair is matched to its own `right_text`. See `score_answer/2` for
    per-pair partial scoring.
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

  def correct_answer?(%__MODULE__{type: :sequence, data: %Data{items: items}}, submitted_ids)
      when is_list(submitted_ids) do
    Enum.map(items, & &1.id) == submitted_ids
  end

  def correct_answer?(%__MODULE__{type: :pin_on_image, data: %Data{pin: %Pin{} = pin}}, answer)
      when is_map(answer) do
    with {:ok, x} <- fetch_coord(answer, "x"),
         {:ok, y} <- fetch_coord(answer, "y") do
      dx = x - pin.target_x
      dy = y - pin.target_y
      :math.sqrt(dx * dx + dy * dy) <= pin.radius
    else
      _ -> false
    end
  end

  def correct_answer?(%__MODULE__{type: :matching} = question, answer) when is_map(answer) do
    case score_answer(question, answer) do
      {n, total} when total > 0 -> n == total
      _ -> false
    end
  end

  def correct_answer?(_question, _input), do: false

  @doc """
  Scores a `:matching` answer as `{correct_count, total}` for partial credit.

  The answer is `%{pair_id => chosen_right_text}`. A pair counts as correct when
  the chosen value equals its `right_text` (whitespace-trimmed, case-insensitive,
  like `:text_input`). Returns `{0, 0}` for non-matching questions or a
  non-map answer.
  """
  def score_answer(%__MODULE__{type: :matching, data: %Data{pairs: pairs}}, answer)
      when is_map(answer) do
    total = length(pairs)

    correct =
      Enum.count(pairs, fn %Pair{id: id, right_text: right_text} ->
        chosen = Map.get(answer, id) || Map.get(answer, to_string(id))
        normalize(chosen) == normalize(right_text) and normalize(right_text) != ""
      end)

    {correct, total}
  end

  def score_answer(_question, _answer), do: {0, 0}

  defp normalize(value), do: value |> to_string() |> String.trim() |> String.downcase()

  defp fetch_coord(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> {:ok, value / 1}
      _ -> :error
    end
  end
end
