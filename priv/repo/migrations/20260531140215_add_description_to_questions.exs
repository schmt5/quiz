defmodule Quiz.Repo.Migrations.AddDescriptionToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      add :description, :text
    end
  end
end
