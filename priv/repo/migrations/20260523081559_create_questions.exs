defmodule Quiz.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions) do
      add :type, :string
      add :prompt, :text
      add :position, :integer
      add :data, :map
      add :game_id, references(:games, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:user_id])

    create index(:questions, [:game_id])
  end
end
