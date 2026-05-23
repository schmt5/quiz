defmodule Quiz.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @join_code_alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  @join_code_length 6

  schema "games" do
    field :title, :string
    field :status, Ecto.Enum, values: [:draft, :open, :running, :finished, :closed]
    field :join_code, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs, user_scope) do
    game
    |> cast(attrs, [:title, :status])
    |> validate_required([:title, :status])
    |> maybe_put_join_code()
    |> unique_constraint(:join_code)
    |> put_change(:user_id, user_scope.user.id)
  end

  defp maybe_put_join_code(changeset) do
    case get_field(changeset, :join_code) do
      nil -> put_change(changeset, :join_code, generate_join_code())
      _ -> changeset
    end
  end

  defp generate_join_code do
    for _ <- 1..@join_code_length, into: "", do: <<Enum.random(@join_code_alphabet)>>
  end
end
