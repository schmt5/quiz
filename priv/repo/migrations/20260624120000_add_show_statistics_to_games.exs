defmodule Quiz.Repo.Migrations.AddShowStatisticsToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :show_statistics, :boolean, null: false, default: false
    end
  end
end
