defmodule Quiz.Repo.Migrations.CascadeDeleteQuestionsWithGame do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      modify :game_id, references(:games, on_delete: :delete_all),
        from: references(:games, on_delete: :nothing)
    end
  end
end
