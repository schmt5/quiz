defmodule Quiz.Repo.Migrations.AddSkippedToQuestions do
  use Ecto.Migration

  # Questions left out of the current run because they were still incomplete
  # when the quiz was opened. Recomputed on every open.
  def change do
    alter table(:questions) do
      add :skipped, :boolean, null: false, default: false
    end
  end
end
