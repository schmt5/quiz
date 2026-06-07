defmodule Quiz.Repo.Migrations.CreateAnswers do
  use Ecto.Migration

  def change do
    create table(:answers) do
      add :payload, :map, null: false
      add :correct, :boolean, null: false, default: false

      add :participant_id, references(:participants, on_delete: :delete_all), null: false
      add :question_id, references(:questions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:answers, [:question_id])
    create unique_index(:answers, [:participant_id, :question_id])
  end
end
