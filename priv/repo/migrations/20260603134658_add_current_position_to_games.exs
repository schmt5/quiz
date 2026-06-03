defmodule Quiz.Repo.Migrations.AddCurrentPositionToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :current_position, :integer
    end
  end
end
