defmodule Quiz.Repo.Migrations.AddMediaImageRevealToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      add :media_image_reveal, :boolean, default: false, null: false
    end
  end
end
