defmodule Quiz.Games.Question do
  use Ecto.Schema
  import Ecto.Changeset

  alias Quiz.Games.Question.{Data, NumberRange, Pair, Pin}

  schema "questions" do
    field :type, Ecto.Enum,
      values: [
        :single_choice,
        :multiple_choice,
        :text_input,
        :sequence,
        :pin_on_image,
        :matching,
        :number_range
      ]

    field :prompt, :string
    field :description, :string
    field :media_image_key, :string
    field :media_video_key, :string
    field :solution_image_key, :string
    field :solution_video_key, :string
    field :solution_text, :string
    # Author notes from the text import (`Quiz.Games.TextFormat`): a description
    # of the image the question needs (its media image, or the pin background
    # for `:pin_on_image`) and where the pin belongs.
    field :image_hint, :string
    field :pin_hint, :string
    # Left out of the current run: still incomplete when the quiz was opened
    # (`Quiz.Play.open_run/3` with `skip_incomplete: true`). Never cast.
    field :skipped, :boolean, default: false
    field :position, :integer
    embeds_one :data, Data, on_replace: :update
    field :game_id, :id
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Authoring changeset for a question.

  `mode` mirrors `Data.changeset/4`:

    * `:draft` (lenient) — only structural rules; the prompt and complete answer
      data may still be missing, so an author can save work in progress.
    * `:publish` (strict, the default) — also requires a prompt and enforces the
      per-type completeness rules a playable question needs.

  The authoring UI passes `:draft` while a quiz is still a draft and `:publish`
  once it has been opened (a live question must stay complete); the publish gate
  uses `ready?/1` to hold the whole quiz to the `:publish` bar before it opens.
  """
  def changeset(question, attrs, user_scope, mode \\ :publish) do
    changeset =
      question
      |> cast(attrs, [
        :type,
        :prompt,
        :description,
        :media_image_key,
        :media_video_key,
        :solution_image_key,
        :solution_video_key,
        :solution_text,
        :image_hint,
        :pin_hint,
        :position,
        :game_id
      ])
      |> validate_required(required_fields(mode))
      |> update_change(:description, &Quiz.HTML.sanitize_description/1)
      |> resolve_media_exclusivity(:media_image_key, :media_video_key)
      |> resolve_media_exclusivity(:solution_image_key, :solution_video_key)
      |> maybe_reset_data_on_type_change()

    type = get_field(changeset, :type)

    changeset
    |> cast_embed(:data, with: &Data.changeset(&1, &2, type, mode))
    |> put_change(:user_id, user_scope.user.id)
  end

  # `:prompt` is a completeness rule (a playable question needs a question text),
  # so it is only required in `:publish` mode; `:type`/`:position`/`:game_id` are
  # structural and always required.
  defp required_fields(:publish), do: [:type, :prompt, :position, :game_id]
  defp required_fields(_draft), do: [:type, :position, :game_id]

  @doc """
  Whether a question meets the `:publish` bar — complete enough to be played.

  This is the whole-question counterpart to the completeness rules in
  `changeset/4`/`Data.changeset/4`: the edit form surfaces them per field, this
  predicate answers pass/fail for the publish gate (`Quiz.Games.open_run`, i.e.
  the `draft -> open` transition). Keep the two in sync.
  """
  def ready?(%__MODULE__{prompt: prompt}) when prompt in [nil, ""], do: false

  def ready?(%__MODULE__{type: :single_choice, data: %Data{choices: choices}}) do
    length(choices) >= 2 and Enum.count(choices, & &1.correct) == 1
  end

  def ready?(%__MODULE__{type: :multiple_choice, data: %Data{choices: choices}}) do
    length(choices) >= 2 and Enum.any?(choices, & &1.correct)
  end

  def ready?(%__MODULE__{type: :text_input, data: %Data{solutions: solutions}}),
    do: solutions != []

  def ready?(%__MODULE__{type: :sequence, data: %Data{items: items}}), do: length(items) >= 2

  def ready?(%__MODULE__{type: :pin_on_image, data: %Data{pin: pin}}), do: not is_nil(pin)

  def ready?(%__MODULE__{type: :matching, data: %Data{pairs: pairs}}) do
    rights = pairs |> Enum.map(&normalize(&1.right_text)) |> Enum.reject(&(&1 == ""))
    length(pairs) >= 2 and rights == Enum.uniq(rights)
  end

  def ready?(%__MODULE__{type: :number_range, data: %Data{number_range: %NumberRange{} = nr}}) do
    is_integer(nr.min) and is_integer(nr.max) and is_integer(nr.solution) and
      is_integer(nr.tolerance) and nr.min < nr.max
  end

  def ready?(%__MODULE__{}), do: false

  @doc """
  Human-readable list of what a question still needs to reach the `:publish` bar
  (empty exactly when `ready?/1` is true).

  Powers the non-blocking "was noch fehlt" hint in the editor so an author can
  see *why* a draft question is not yet playable, without being blocked from
  saving. Keep in sync with `ready?/1` and `Data.changeset/4`.
  """
  def missing_requirements(%__MODULE__{} = question) do
    prompt_missing(question.prompt) ++ data_missing(question.type, question.data || %Data{})
  end

  @doc """
  Whether the question still waits for an image the author has to upload: a
  `:pin_on_image` question without its background, or any other question whose
  `image_hint` (from the text import) asks for an image that is not there yet.
  """
  def image_missing?(%__MODULE__{type: :pin_on_image, data: data}) do
    not match?(%Data{pin: %Pin{image_key: key}} when is_binary(key) and key != "", data)
  end

  def image_missing?(%__MODULE__{image_hint: hint} = question) do
    hint not in [nil, ""] and question.media_image_key in [nil, ""] and
      question.media_video_key in [nil, ""]
  end

  defp prompt_missing(prompt) do
    if prompt in [nil, ""] or String.trim(to_string(prompt)) == "",
      do: ["ein Fragetext"],
      else: []
  end

  defp data_missing(:single_choice, %Data{choices: choices}) do
    []
    |> add_if(length(choices) < 2, "mindestens zwei Antwortmöglichkeiten")
    |> add_if(Enum.count(choices, & &1.correct) != 1, "eine als richtig markierte Antwort")
  end

  defp data_missing(:multiple_choice, %Data{choices: choices}) do
    []
    |> add_if(length(choices) < 2, "mindestens zwei Antwortmöglichkeiten")
    |> add_if(
      not Enum.any?(choices, & &1.correct),
      "mindestens eine als richtig markierte Antwort"
    )
  end

  defp data_missing(:text_input, %Data{solutions: solutions}),
    do: add_if([], solutions == [], "mindestens eine akzeptierte Lösung")

  defp data_missing(:sequence, %Data{items: items}),
    do: add_if([], length(items) < 2, "mindestens zwei Einträge")

  defp data_missing(:pin_on_image, %Data{pin: pin}),
    do: add_if([], is_nil(pin), "ein Bild mit markiertem Ziel")

  defp data_missing(:matching, %Data{pairs: pairs}) do
    rights = pairs |> Enum.map(&normalize(&1.right_text)) |> Enum.reject(&(&1 == ""))

    []
    |> add_if(length(pairs) < 2, "mindestens zwei Paare")
    |> add_if(rights != Enum.uniq(rights), "eindeutige Zuordnungen (rechte Spalte)")
  end

  defp data_missing(:number_range, %Data{number_range: nr}) do
    ready? =
      match?(%NumberRange{}, nr) and is_integer(nr.min) and is_integer(nr.max) and
        is_integer(nr.solution) and is_integer(nr.tolerance) and nr.min < nr.max

    add_if([], not ready?, "Minimum, Maximum, Lösung und Toleranz (Min < Max)")
  end

  defp data_missing(_type, _data), do: []

  defp add_if(list, true, message), do: list ++ [message]
  defp add_if(list, false, _message), do: list

  @doc """
  Lenient changeset for the instant-create flow.

  Picking a type persists a skeleton question immediately, so `:prompt` and the
  type-specific `:data` are intentionally *not* required here — they are filled
  in and validated later through `changeset/3` in the edit form.
  """
  def create_changeset(question, attrs, user_scope) do
    question
    |> cast(attrs, [:type, :position, :game_id])
    |> validate_required([:type, :position, :game_id])
    |> put_change(:user_id, user_scope.user.id)
  end

  # A medium slot carries either an image or a video, never both. Whichever one
  # was set in this cast wins and clears the other; only setting both at once is
  # an error. This runs in `:draft` mode too — media is optional, but a conflict
  # is structural, not incompleteness. Applied to both slots: the question's own
  # media and the solution explanation.
  defp resolve_media_exclusivity(changeset, image_field, video_field) do
    image = fetch_change(changeset, image_field)
    video = fetch_change(changeset, video_field)

    cond do
      match?({:ok, value} when not is_nil(value), image) and
          match?({:ok, value} when not is_nil(value), video) ->
        add_error(changeset, video_field, "Bild oder Video – nicht beides")

      match?({:ok, value} when not is_nil(value), image) ->
        put_change(changeset, video_field, nil)

      match?({:ok, value} when not is_nil(value), video) ->
        put_change(changeset, image_field, nil)

      true ->
        changeset
    end
  end

  defp maybe_reset_data_on_type_change(changeset) do
    with {:ok, _new_type} <- fetch_change(changeset, :type),
         %Data{} <- get_field(changeset, :data) do
      # Clear the existing embed in-place; on_replace: :update requires a map
      # (not a struct). cast_embed afterwards will populate from the new attrs.
      put_embed(changeset, :data, %{
        choices: [],
        solutions: [],
        items: [],
        pairs: [],
        pin: nil,
        number_range: nil
      })
    else
      _ -> changeset
    end
  end

  @doc """
  Checks a user's answer against a question.

  - `:text_input`: case-insensitive + whitespace-trimmed comparison against any
    configured solution.
  - `:single_choice`: the answer is the 0-based index of the chosen choice.
  - `:multiple_choice`: the answer is a list of 0-based indices; correct only when
    every correct choice was picked and no incorrect one was. See `score_answer/2`
    for the partial scoring.
  - `:pin_on_image`: the answer is `%{"x" => float, "y" => float}` (normalized
    `0..1`); correct when it falls within the target's tolerance radius.
  - `:matching`: the answer is `%{pair_id => chosen_right_text}`; correct when
    every pair is matched to its own `right_text`. See `score_answer/2` for
    per-pair partial scoring.
  - `:number_range`: the answer is an integer guess; correct when it lies within
    `solution ± tolerance`.
  """
  def correct_answer?(%__MODULE__{type: :text_input, data: %Data{solutions: solutions}}, input) do
    normalized = input |> to_string() |> String.trim() |> String.downcase()

    Enum.any?(solutions, fn %{text: text} ->
      String.downcase(String.trim(text || "")) == normalized
    end)
  end

  def correct_answer?(%__MODULE__{type: :single_choice, data: %Data{choices: choices}}, index)
      when is_integer(index) do
    case Enum.at(choices, index) do
      %{correct: true} -> true
      _ -> false
    end
  end

  def correct_answer?(%__MODULE__{type: :multiple_choice} = question, indices)
      when is_list(indices) do
    case score_answer(question, indices) do
      {n, total} when total > 0 -> n == total
      _ -> false
    end
  end

  def correct_answer?(%__MODULE__{type: :sequence, data: %Data{items: items}}, submitted_ids)
      when is_list(submitted_ids) do
    Enum.map(items, & &1.id) == submitted_ids
  end

  def correct_answer?(%__MODULE__{type: :pin_on_image, data: %Data{pin: %Pin{} = pin}}, answer)
      when is_map(answer) do
    with {:ok, x} <- fetch_coord(answer, "x"),
         {:ok, y} <- fetch_coord(answer, "y") do
      ar = pin.aspect_ratio || 1.0
      dx = x - pin.target_x
      # `radius` is normalized to the box width, so the vertical delta is scaled
      # by the aspect ratio to keep the tolerance a true circle (see Pin docs).
      dy = (y - pin.target_y) / ar
      :math.sqrt(dx * dx + dy * dy) <= pin.radius
    else
      _ -> false
    end
  end

  def correct_answer?(%__MODULE__{type: :matching} = question, answer) when is_map(answer) do
    case score_answer(question, answer) do
      {n, total} when total > 0 -> n == total
      _ -> false
    end
  end

  def correct_answer?(
        %__MODULE__{type: :number_range, data: %Data{number_range: %NumberRange{} = nr}},
        guess
      )
      when is_number(guess) do
    abs(guess - nr.solution) <= nr.tolerance
  end

  def correct_answer?(_question, _input), do: false

  @doc """
  Scores a `:matching` or `:multiple_choice` answer as `{score, total}` for
  partial credit.

  For `:matching` the answer is `%{pair_id => chosen_right_text}`. A pair counts as
  correct when the chosen value equals its `right_text` (whitespace-trimmed,
  case-insensitive, like `:text_input`).

  For `:multiple_choice` the answer is a list of 0-based indices. Wrong picks are
  subtracted from the hits (floored at zero), so `score == total` means "every
  correct option and nothing else" — which is exactly what `correct_answer?/2`
  checks — while a merely partial selection stays above zero and earns `:half`
  in `Quiz.Play.auto_grade/2`.

  Returns `{0, 0}` for any other question type or a malformed answer.
  """
  def score_answer(%__MODULE__{type: :matching, data: %Data{pairs: pairs}}, answer)
      when is_map(answer) do
    total = length(pairs)

    correct =
      Enum.count(pairs, fn %Pair{id: id, right_text: right_text} ->
        chosen = Map.get(answer, id) || Map.get(answer, to_string(id))
        normalize(chosen) == normalize(right_text) and normalize(right_text) != ""
      end)

    {correct, total}
  end

  def score_answer(%__MODULE__{type: :multiple_choice, data: %Data{choices: choices}}, indices)
      when is_list(indices) do
    correct =
      choices
      |> Enum.with_index()
      |> Enum.filter(fn {choice, _i} -> choice.correct end)
      |> MapSet.new(fn {_choice, i} -> i end)

    # Out-of-range indices can only come from a crafted request; drop them rather
    # than letting them count as wrong picks.
    n = length(choices)

    picked =
      indices
      |> Enum.map(&to_index/1)
      |> Enum.filter(&(is_integer(&1) and &1 < n))
      |> MapSet.new()

    hits = picked |> MapSet.intersection(correct) |> MapSet.size()
    wrong = picked |> MapSet.difference(correct) |> MapSet.size()

    {max(hits - wrong, 0), MapSet.size(correct)}
  end

  def score_answer(_question, _answer), do: {0, 0}

  # Indices survive a JSONB round-trip as integers, but a raw form value may still
  # arrive as a string; anything else is not a choice index.
  defp to_index(i) when is_integer(i) and i >= 0, do: i

  defp to_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} when i >= 0 -> i
      _ -> nil
    end
  end

  defp to_index(_), do: nil

  defp normalize(value), do: value |> to_string() |> String.trim() |> String.downcase()

  defp fetch_coord(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> {:ok, value / 1}
      _ -> :error
    end
  end
end
