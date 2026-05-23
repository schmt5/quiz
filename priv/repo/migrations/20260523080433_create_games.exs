defmodule Quiz.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :title, :string
      add :status, :string
      add :join_code, :string
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:user_id])

    create unique_index(:games, [:join_code])
  end
end
