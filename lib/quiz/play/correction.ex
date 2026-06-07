defmodule Quiz.Play.Correction do
  @moduledoc """
  Per-question correction state for a run. `done` records that the corrector has
  finalised ("Fertig") the grading of one question for the whole class. There is
  at most one row per question (one inline run per game).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "corrections" do
    field :done, :boolean, default: false
    field :question_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(correction, attrs) do
    correction
    |> cast(attrs, [:done, :question_id])
    |> validate_required([:done, :question_id])
    |> unique_constraint(:question_id)
  end
end
