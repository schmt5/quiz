defmodule Quiz.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @join_code_alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  @join_code_length 6

  # Allowed `status` transitions for a quiz run. The authoring `changeset/3`
  # owns the initial `:draft` state; every runtime transition goes through
  # `transition_changeset/2`, which rejects any `from -> to` pair not listed
  # here, keeping the state machine explicit and total.
  @transitions %{
    draft: [:open],
    open: [:running, :closed],
    running: [:finished, :closed],
    finished: [:closed],
    closed: [:open]
  }

  schema "games" do
    field :title, :string
    field :status, Ecto.Enum, values: [:draft, :open, :running, :finished, :closed]
    field :join_code, :string
    field :current_position, :integer
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

  @doc """
  Changeset for a runtime status transition (e.g. opening or starting a run).

  Only `:status` and `:current_position` may change. The `from -> to` status
  pair must be listed in `@transitions`, otherwise the changeset is invalid.
  Unlike `changeset/3` this never regenerates the `join_code` or touches the
  owner.
  """
  def transition_changeset(%__MODULE__{} = game, attrs) do
    game
    |> cast(attrs, [:status, :current_position])
    |> validate_required([:status])
    |> validate_transition(game.status)
  end

  defp validate_transition(changeset, from) do
    to = get_field(changeset, :status)
    allowed = Map.get(@transitions, from, [])

    if to == from or to in allowed do
      changeset
    else
      add_error(changeset, :status, "ungültiger Übergang von #{from} zu #{to}")
    end
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
