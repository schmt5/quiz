defmodule Quiz.Repo.Migrations.AddReviewModeAndRevealingToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :review_mode, :string, null: false, default: "end"
      add :revealing, :boolean, null: false, default: false
    end
  end
end
