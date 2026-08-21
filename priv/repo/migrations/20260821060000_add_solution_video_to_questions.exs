defmodule Quiz.Repo.Migrations.AddSolutionVideoToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      add :solution_video_key, :string
    end
  end
end
