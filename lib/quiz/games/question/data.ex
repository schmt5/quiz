defmodule Quiz.Games.Question.Data do
  @moduledoc """
  Type-specific payload for a `Quiz.Games.Question`.

  A single embedded schema holds the union of all type-specific fields. The
  parent `Question.changeset/3` dispatches by `:type` and validates only the
  relevant subset; the irrelevant fields are reset.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Quiz.Games.Question.{Choice, Item, Pair, Pin, Solution}

  @primary_key false
  embedded_schema do
    embeds_many :choices, Choice, on_replace: :delete
    embeds_many :solutions, Solution, on_replace: :delete
    embeds_many :items, Item, on_replace: :delete
    embeds_many :pairs, Pair, on_replace: :delete
    embeds_one :pin, Pin, on_replace: :update
  end

  @doc """
  Builds a changeset for the embedded data based on the parent question's `type`.

  `mode` controls how strict the validation is:

    * `:draft` — only *structural* rules run (the type-specific embed is cast and,
      for `:matching`, right-texts must stay unique so scoring stays unambiguous).
      This lets an author save a half-finished question and complete it later.
    * `:publish` — additionally enforces the *completeness* rules a playable
      question needs (enough choices/items/pairs, exactly one correct answer, a
      pin image, at least one solution). Applied when a quiz leaves `:draft`
      (see `Quiz.Games.open-gate`) and whenever a live question is edited.

  `validate_unique_right_text/1` is deliberately *structural* (always on): a
  duplicate right-text breaks the 1:1 mapping `Question.score_answer/2` relies on,
  which would silently mis-grade rather than merely look incomplete.
  """
  def changeset(data, attrs, type, mode \\ :publish)

  def changeset(data, attrs, :single_choice, mode) do
    data
    |> cast(attrs, [])
    |> put_embed(:solutions, [])
    |> put_embed(:items, [])
    |> put_embed(:pairs, [])
    |> put_embed(:pin, nil)
    |> cast_embed(:choices,
      with: &Choice.changeset/2,
      sort_param: :choices_sort,
      drop_param: :choices_drop
    )
    |> when_publish(mode, fn changeset ->
      changeset
      |> validate_length(:choices, min: 2, message: "mind. zwei Antwortmöglichkeiten")
      |> validate_exactly_one_correct()
    end)
  end

  def changeset(data, attrs, :text_input, mode) do
    data
    |> cast(attrs, [])
    |> put_embed(:choices, [])
    |> put_embed(:items, [])
    |> put_embed(:pairs, [])
    |> put_embed(:pin, nil)
    |> cast_embed(:solutions,
      with: &Solution.changeset/2,
      sort_param: :solutions_sort,
      drop_param: :solutions_drop
    )
    |> when_publish(mode, &validate_length(&1, :solutions, min: 1, message: "mind. eine Lösung"))
  end

  def changeset(data, attrs, :sequence, mode) do
    data
    |> cast(attrs, [])
    |> put_embed(:choices, [])
    |> put_embed(:solutions, [])
    |> put_embed(:pairs, [])
    |> put_embed(:pin, nil)
    |> cast_embed(:items,
      with: &Item.changeset/2,
      sort_param: :items_sort,
      drop_param: :items_drop
    )
    |> when_publish(mode, &validate_length(&1, :items, min: 2, message: "mind. zwei Einträge"))
  end

  def changeset(data, attrs, :pin_on_image, mode) do
    data
    |> cast(attrs, [])
    |> put_embed(:choices, [])
    |> put_embed(:solutions, [])
    |> put_embed(:items, [])
    |> put_embed(:pairs, [])
    |> cast_embed(:pin, with: &Pin.changeset/2, required: mode == :publish)
  end

  def changeset(data, attrs, :matching, mode) do
    data
    |> cast(attrs, [])
    |> put_embed(:choices, [])
    |> put_embed(:solutions, [])
    |> put_embed(:items, [])
    |> put_embed(:pin, nil)
    |> cast_embed(:pairs,
      with: &Pair.changeset/2,
      sort_param: :pairs_sort,
      drop_param: :pairs_drop
    )
    |> validate_unique_right_text()
    |> when_publish(mode, &validate_length(&1, :pairs, min: 2, message: "mind. zwei Paare"))
  end

  # No type yet (initial render before the user picked one) — no-op.
  def changeset(data, _attrs, _no_type_yet, _mode), do: cast(data, %{}, [])

  # Runs `fun` only in `:publish` mode; a no-op while drafting.
  defp when_publish(changeset, :publish, fun), do: fun.(changeset)
  defp when_publish(changeset, _mode, _fun), do: changeset

  # Each right value must be unique so a submitted match maps to exactly one
  # pair (keeps the 1:1 bijection and scoring unambiguous). Case-insensitive,
  # mirroring how matches are scored.
  defp validate_unique_right_text(changeset) do
    rights =
      changeset
      |> get_field(:pairs, [])
      |> Enum.map(fn pair ->
        pair.right_text |> to_string() |> String.trim() |> String.downcase()
      end)
      |> Enum.reject(&(&1 == ""))

    if rights == Enum.uniq(rights) do
      changeset
    else
      add_error(changeset, :pairs, "die Zuordnungen müssen eindeutig sein")
    end
  end

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
