defmodule Quiz.Repo.Migrations.CreateCorrections do
  use Ecto.Migration

  def change do
    create table(:corrections) do
      add :done, :boolean, null: false, default: false
      add :question_id, references(:questions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:corrections, [:question_id])
  end
end
