defmodule Quiz.Games.Question.Data do
  @moduledoc """
  Type-specific payload for a `Quiz.Games.Question`.

  A single embedded schema holds the union of all type-specific fields. The
  parent `Question.changeset/3` dispatches by `:type` and validates only the
  relevant subset; the irrelevant fields are reset.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Quiz.Games.Question.{Choice, Item, Solution}

  @primary_key false
  embedded_schema do
    embeds_many :choices, Choice, on_replace: :delete
    embeds_many :solutions, Solution, on_replace: :delete
    embeds_many :items, Item, on_replace: :delete
  end

  @doc """
  Builds a changeset for the embedded data based on the parent question's `type`.
  """
  def changeset(data, attrs, :single_choice) do
    data
    |> cast(attrs, [])
    |> put_embed(:solutions, [])
    |> put_embed(:items, [])
    |> cast_embed(:choices,
      with: &Choice.changeset/2,
      sort_param: :choices_sort,
      drop_param: :choices_drop
    )
    |> validate_length(:choices, min: 2, message: "mind. zwei Antwortmöglichkeiten")
    |> validate_exactly_one_correct()
  end

  def changeset(data, attrs, :text_input) do
    data
    |> cast(attrs, [])
    |> put_embed(:choices, [])
    |> put_embed(:items, [])
    |> cast_embed(:solutions,
      with: &Solution.changeset/2,
      sort_param: :solutions_sort,
      drop_param: :solutions_drop
    )
    |> validate_length(:solutions, min: 1, message: "mind. eine Lösung")
  end

  def changeset(data, attrs, :sequence) do
    data
    |> cast(attrs, [])
    |> put_embed(:choices, [])
    |> put_embed(:solutions, [])
    |> cast_embed(:items,
      with: &Item.changeset/2,
      sort_param: :items_sort,
      drop_param: :items_drop
    )
    |> validate_length(:items, min: 2, message: "mind. zwei Einträge")
  end

  # No type yet (initial render before the user picked one) — no-op.
  def changeset(data, _attrs, _no_type_yet), do: cast(data, %{}, [])

  defp validate_exactly_one_correct(changeset) do
    correct_count =
      changeset
      |> get_field(:choices, [])
      |> Enum.count(& &1.correct)

    case correct_count do
      1 -> changeset
      0 -> add_error(changeset, :choices, "eine Antwort muss als richtig markiert sein")
      _ -> add_error(changeset, :choices, "nur eine Antwort darf als richtig markiert sein")
    end
  end
end
