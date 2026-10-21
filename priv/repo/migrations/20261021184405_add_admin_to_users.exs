defmodule Quiz.Repo.Migrations.AddAdminToUsers do
  use Ecto.Migration

  # Nobody is granted admin here on purpose: with registration opening up,
  # "has an account" no longer means "operator". Grant it explicitly after the
  # deploy with `bin/quiz eval 'Quiz.Release.grant_admin("…")'`.
  def change do
    alter table(:users) do
      add :admin, :boolean, null: false, default: false
    end
  end
end
