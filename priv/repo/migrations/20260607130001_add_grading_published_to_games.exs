defmodule Quiz.Repo.Migrations.AddGradingPublishedToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :grading_published, :boolean, null: false, default: false
    end
  end
end
