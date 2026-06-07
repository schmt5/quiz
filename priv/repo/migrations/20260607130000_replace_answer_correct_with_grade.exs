defmodule Quiz.Repo.Migrations.ReplaceAnswerCorrectWithGrade do
  use Ecto.Migration

  def up do
    alter table(:answers) do
      add :grade, :string, null: false, default: "zero"
    end

    execute "UPDATE answers SET grade = 'full' WHERE correct = true"

    alter table(:answers) do
      remove :correct
    end
  end

  def down do
    alter table(:answers) do
      add :correct, :boolean, null: false, default: false
    end

    execute "UPDATE answers SET correct = true WHERE grade = 'full'"

    alter table(:answers) do
      remove :grade
    end
  end
end
