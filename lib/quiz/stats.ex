defmodule Quiz.Stats do
  @moduledoc """
  Anonymous answer statistics for the post-quiz solution walkthrough.

  This is the *distribution* of what the room answered — never which answer was
  correct. Correctness lives in `QuizWeb.QuestionLive.SolutionArea`; the two are
  deliberately kept separate (see `QuizWeb.QuestionLive.StatsArea`). As a
  consequence these numbers do not depend on correction having been done.

  `question_stats/2` returns a type-tagged map that `StatsArea` pattern-matches:

    * `:single_choice` / `:text_input` — `:rows` of `%{label, count, pct}`,
      most-common first.
    * `:sequence` — `:rows` of distinct orderings (`%{labels, count, pct}`),
      most-common first, with `:more` counting any collapsed tail.
    * `:matching` — `:pairs`, each with the per-left distribution of chosen
      right-sides (`:rows` + `:more`).
    * `:pin_on_image` — `:points` of `%{x, y}` for an overlay, plus `:image_key`.

  Every result carries `:answered` (teams that gave a non-blank answer),
  `:total` (enrolled teams), and `:blank` (`total - answered`).
  """

  import Ecto.Query, warn: false

  alias Quiz.Repo
  alias Quiz.Games.Question
  alias Quiz.Play.Answer

  # How many rows a "busy" type (sequence orderings, matching choices per pair)
  # shows before collapsing the rest into a "+N weitere" tail.
  @top_n 5

  @doc """
  Computes the anonymous distribution for `question` over its stored answers.

  `total_participants` is the number of enrolled teams, used as the denominator
  for percentages and to derive the blank ("keine Antwort") count.
  """
  def question_stats(%Question{} = question, total_participants)
      when is_integer(total_participants) do
    values =
      Answer
      |> where([a], a.question_id == ^question.id)
      |> select([a], a.payload)
      |> Repo.all()
      |> Enum.map(&value/1)

    compute(question, values, total_participants)
  end

  defp value(%{"value" => v}), do: v
  defp value(_), do: nil

  ## Per-type aggregation ---------------------------------------------------

  defp compute(%Question{type: :single_choice, data: %{choices: choices}}, values, total) do
    n = length(choices)
    counts = Enum.frequencies(for v <- values, is_integer(v) and v >= 0 and v < n, do: v)

    rows =
      choices
      |> Enum.with_index()
      |> Enum.map(fn {choice, i} ->
        count = Map.get(counts, i, 0)
        %{label: choice.text, count: count, pct: pct(count, total)}
      end)
      |> Enum.sort_by(& &1.count, :desc)

    answered = counts |> Map.values() |> Enum.sum()
    base(:single_choice, answered, total) |> Map.put(:rows, rows)
  end

  defp compute(%Question{type: :text_input}, values, total) do
    groups =
      values
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(normalize(&1) == ""))
      |> Enum.group_by(&normalize/1)

    rows =
      groups
      |> Enum.map(fn {_key, members} ->
        %{label: most_common(members), count: length(members), pct: pct(length(members), total)}
      end)
      |> Enum.sort_by(& &1.count, :desc)

    answered = Enum.sum(Enum.map(rows, & &1.count))
    base(:text_input, answered, total) |> Map.put(:rows, rows)
  end

  defp compute(%Question{type: :sequence, data: %{items: items}}, values, total) do
    texts = Map.new(items, &{&1.id, &1.text})

    orderings = for v <- values, is_list(v) and v != [], do: v

    ranked =
      orderings
      |> Enum.frequencies()
      |> Enum.map(fn {ids, count} ->
        %{
          labels: Enum.map(ids, &Map.get(texts, &1, "?")),
          count: count,
          pct: pct(count, total)
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)

    {rows, more} = take_top(ranked)

    base(:sequence, length(orderings), total)
    |> Map.merge(%{rows: rows, more: more})
  end

  defp compute(%Question{type: :matching, data: %{pairs: pairs}}, values, total) do
    maps = for v <- values, is_map(v) and map_size(v) > 0, do: v

    pair_rows =
      Enum.map(pairs, fn pair ->
        chosen =
          maps
          |> Enum.map(fn map -> Map.get(map, pair.id) || Map.get(map, to_string(pair.id)) end)
          |> Enum.map(&to_string/1)
          |> Enum.reject(&(String.trim(&1) == ""))

        ranked =
          chosen
          |> Enum.group_by(&normalize/1)
          |> Enum.map(fn {_k, members} ->
            %{label: most_common(members), count: length(members), pct: pct(length(members), total)}
          end)
          |> Enum.sort_by(& &1.count, :desc)

        {rows, more} = take_top(ranked)
        %{left: pair.left_text, rows: rows, more: more}
      end)

    base(:matching, length(maps), total) |> Map.put(:pairs, pair_rows)
  end

  defp compute(%Question{type: :pin_on_image, data: %{pin: pin}}, values, total) do
    points =
      for v <- values, p = point(v), not is_nil(p), do: p

    base(:pin_on_image, length(points), total)
    |> Map.merge(%{image_key: pin && pin.image_key, points: points})
  end

  defp compute(%Question{type: type}, _values, total) do
    base(type, 0, total)
  end

  ## Helpers ----------------------------------------------------------------

  defp base(type, answered, total) do
    %{type: type, answered: answered, total: total, blank: max(total - answered, 0)}
  end

  defp point(%{"x" => x, "y" => y}) when is_number(x) and is_number(y), do: %{x: x, y: y}
  defp point(_), do: nil

  defp pct(_count, total) when total <= 0, do: 0
  defp pct(count, total), do: round(count * 100 / total)

  defp normalize(value), do: value |> to_string() |> String.trim() |> String.downcase()

  # Most frequent original spelling among case-insensitively equal answers, so
  # "Paris" wins over "paris" when it occurs more often. Ties resolve to the
  # first-seen spelling (`max_by` keeps the first maximal element, and `uniq`
  # preserves occurrence order).
  defp most_common(members) do
    trimmed = Enum.map(members, &String.trim(to_string(&1)))
    freq = Enum.frequencies(trimmed)

    trimmed
    |> Enum.uniq()
    |> Enum.max_by(&Map.fetch!(freq, &1))
  end

  defp take_top(ranked) do
    rows = Enum.take(ranked, @top_n)
    more = length(ranked) - length(rows)
    {rows, more}
  end
end
