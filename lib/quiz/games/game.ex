defmodule Quiz.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  # Join codes are 4-digit PINs in the range 1000–9999 (no leading zeros, so
  # they always render as four visible digits). Uniqueness is enforced by the
  # `join_code` unique index; `Quiz.Games.insert_game/3` retries on collision.
  @join_code_range 1000..9999

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

    field :status, Ecto.Enum,
      values: [:draft, :open, :running, :finished, :closed],
      default: :draft

    field :join_code, :string
    field :current_position, :integer
    field :grading_published, :boolean, default: false
    field :show_statistics, :boolean, default: false
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Authoring changeset for creating and editing a game's content.

  Status is deliberately *not* castable here: a new game always starts in
  `:draft` (the schema default) and every later status change goes through
  `transition_changeset/2`, which enforces the state machine. The user can
  never pick a status directly.
  """
  def changeset(game, attrs, user_scope) do
    game
    |> cast(attrs, [:title, :show_statistics])
    |> validate_required([:title])
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
    @join_code_range |> Enum.random() |> Integer.to_string()
  end
end
