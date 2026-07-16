defmodule Quiz.Repo.Migrations.AddEnrollmentLockedToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :enrollment_locked, :boolean, default: false, null: false
    end
  end
end
