defmodule Quiz.Games.Question.Choice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :text, :string
    field :correct, :boolean, default: false
  end

  @doc false
  def changeset(choice, attrs) do
    choice
    |> cast(attrs, [:text, :correct])
    |> update_change(:text, fn
      nil -> nil
      text -> String.trim(text)
    end)
    |> validate_required([:text])
    |> validate_length(:text, min: 1)
  end
end
