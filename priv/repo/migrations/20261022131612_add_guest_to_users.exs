defmodule Quiz.Repo.Migrations.AddGuestToUsers do
  use Ecto.Migration

  # Guest accounts let visitors try the app without registering. They expire
  # and are deleted (with their quizzes and uploads) by Quiz.Accounts.GuestCleanup.
  def change do
    alter table(:users) do
      add :guest, :boolean, null: false, default: false
      add :expires_at, :utc_datetime
    end

    create index(:users, [:expires_at], where: "guest")
  end
end
