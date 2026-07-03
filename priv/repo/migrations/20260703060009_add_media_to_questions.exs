defmodule Quiz.Repo.Migrations.AddMediaToQuestions do
  use Ecto.Migration

  def change do
    alter table(:questions) do
      add :media_image_key, :string
      add :media_video_key, :string
    end
  end
end
