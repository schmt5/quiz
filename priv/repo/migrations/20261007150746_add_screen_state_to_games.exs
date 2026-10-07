defmodule Quiz.Repo.Migrations.AddScreenStateToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :screen_view, :string, default: "run", null: false
      add :screen_position, :integer
      add :screen_show_stats, :boolean, default: false, null: false
    end
  end
end
