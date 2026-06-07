defmodule Quiz.Play.Answer do
  @moduledoc """
  A team's answer to a single question within a run.

  `payload` stores the answer wrapped as `%{"value" => canonical}`, where
  `canonical` is exactly what `Quiz.Games.Question.correct_answer?/2` expects for
  the question's type (a string, a choice index, a list of item ids, a
  `pair_id => right_text` map, or `%{"x" => float, "y" => float}`). Storing it
  this way lets us both re-score and re-display the answer later.

  `grade` is the three-state verdict (`:full | :half | :zero`), seeded by
  auto-grading and overridable by the corrector. See `points/1`.

  There is at most one answer per `(participant_id, question_id)`; resubmits
  upsert it (latest wins).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "answers" do
    field :payload, :map
    field :grade, Ecto.Enum, values: [:full, :half, :zero], default: :zero
    field :participant_id, :id
    field :question_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc "Points awarded for a grade: full = 1, half = 0.5, zero = 0."
  def points(:full), do: 1.0
  def points(:half), do: 0.5
  def points(:zero), do: 0.0

  @doc false
  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:payload, :grade, :participant_id, :question_id])
    |> validate_required([:payload, :grade, :participant_id, :question_id])
    |> unique_constraint([:participant_id, :question_id])
  end
end
