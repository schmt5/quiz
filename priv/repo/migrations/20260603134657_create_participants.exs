defmodule Quiz.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants) do
      add :name, :string, null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:participants, [:game_id])
    create unique_index(:participants, [:game_id, :name])
  end
end
