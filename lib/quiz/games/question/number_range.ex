defmodule Quiz.Games.Question.NumberRange do
  @moduledoc """
  Type-specific payload for a `:number_range` question.

  The author gives a `min`/`max` (the plausible bounds shown to the participant),
  a `solution` (the true value) and a `tolerance`. The participant enters a single
  number; a guess is correct when it lies within `solution ± tolerance` (see
  `Question.correct_answer?/2`). All four values are whole numbers.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :min, :integer
    field :max, :integer
    field :solution, :integer
    field :tolerance, :integer
  end

  @doc false
  def changeset(number_range, attrs) do
    number_range
    |> cast(attrs, [:min, :max, :solution, :tolerance])
    |> validate_required([:min, :max, :solution, :tolerance])
    |> validate_number(:tolerance, greater_than_or_equal_to: 0)
    |> validate_min_below_max()
  end

  # `min` must be below `max`, but only check once both are present so a
  # half-filled draft stays saveable.
  defp validate_min_below_max(changeset) do
    min = get_field(changeset, :min)
    max = get_field(changeset, :max)

    if is_integer(min) and is_integer(max) and min >= max do
      add_error(changeset, :max, "muss grösser als das Minimum sein")
    else
      changeset
    end
  end
end
