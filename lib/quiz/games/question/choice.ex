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
    |> validate_required([:text])
  end
end
