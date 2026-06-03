defmodule Quiz.Games.Question.Pair do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :left_text, :string
    field :right_text, :string
  end

  @doc false
  def changeset(pair, attrs) do
    pair
    |> cast(attrs, [:left_text, :right_text])
    |> update_change(:left_text, &trim/1)
    |> update_change(:right_text, &trim/1)
    |> validate_required([:left_text, :right_text])
    |> validate_length(:left_text, min: 1)
    |> validate_length(:right_text, min: 1)
  end

  defp trim(nil), do: nil
  defp trim(text), do: String.trim(text)
end
