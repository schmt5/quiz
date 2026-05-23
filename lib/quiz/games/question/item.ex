defmodule Quiz.Games.Question.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :text, :string
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:text])
    |> update_change(:text, fn
      nil -> nil
      text -> String.trim(text)
    end)
    |> validate_required([:text])
    |> validate_length(:text, min: 1)
  end
end
