defmodule Quiz.Repo.Migrations.AddSolutionExplanationToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      add :solution_image_key, :string
      add :solution_text, :text
    end
  end
end
