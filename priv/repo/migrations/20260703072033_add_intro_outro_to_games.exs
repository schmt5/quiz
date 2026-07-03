defmodule Quiz.Repo.Migrations.AddIntroOutroToGames do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :intro_text, :text
      add :intro_image_key, :string
      add :outro_text, :text
      add :outro_image_key, :string
    end
  end
end
