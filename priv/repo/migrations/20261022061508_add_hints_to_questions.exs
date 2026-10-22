defmodule Quiz.Repo.Migrations.AddHintsToQuestions do
  use Ecto.Migration

  # Notes for the author on what is still to be added by hand — written by the
  # AI import, which cannot supply images: which image the question needs, and
  # (for pin-on-image) where the pin belongs.
  def change do
    alter table(:questions) do
      add :image_hint, :text
      add :pin_hint, :text
    end
  end
end
