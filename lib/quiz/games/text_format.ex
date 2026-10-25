defmodule Quiz.Games.TextFormat do
  @moduledoc """
  The plain-text quiz format (`quiz-text/v1`): what AI chats produce following
  the guide in `priv/prompts/ki-anleitung.md`, and what a quiz is exported as.

      Format: quiz-text/v1
      Quiz: Pilze der Schweiz

      Frage: Welcher Pilz ist tödlich giftig?
      Typ: Single-Choice
      - Steinpilz
      - [x] Grüner Knollenblätterpilz
      Erklärung: …

  `parse/1` turns such text into attribute maps for `Quiz.Games.import_game/2`;
  `render/2` turns a game back into text. Parsing is deliberately forgiving,
  because the text comes from free AI models and is pasted by hand: chatter
  around a code block, Markdown bold, numbered `Frage:` lines, synonyms and
  Swiss thousands separators are accepted. A problem only ever affects the one
  question it occurs in; it is reported as a warning and the rest still
  imports. The resulting data always passes `Question.changeset/4` in `:draft`
  mode, so completeness (e.g. a marked answer) is left to the editor's usual
  `Question.missing_requirements/1` hints.
  """

  alias Quiz.Games.{Game, Question}
  alias Quiz.Games.Question.{Data, NumberRange}

  @version "quiz-text/v1"

  # The names the question editor shows, so the AI text and the app agree.
  @type_names [
    single_choice: "Single-Choice",
    multiple_choice: "Multiple-Choice",
    text_input: "Texteingabe",
    sequence: "Reihenfolge",
    matching: "Zuordnung",
    number_range: "Zahlenschätzung",
    pin_on_image: "Pin auf Bild"
  ]

  @type_aliases %{
    "einfachauswahl" => :single_choice,
    "einzelauswahl" => :single_choice,
    "singlechoice" => :single_choice,
    "auswahl" => :single_choice,
    "mehrfachauswahl" => :multiple_choice,
    "multiplechoice" => :multiple_choice,
    "texteingabe" => :text_input,
    "textantwort" => :text_input,
    "freitext" => :text_input,
    "textinput" => :text_input,
    "reihenfolge" => :sequence,
    "sortieren" => :sequence,
    "sortierung" => :sequence,
    "sequence" => :sequence,
    "zuordnung" => :matching,
    "zuordnen" => :matching,
    "matching" => :matching,
    "schätzfrage" => :number_range,
    "schaetzfrage" => :number_range,
    "schätzung" => :number_range,
    "schaetzung" => :number_range,
    "zahl" => :number_range,
    "zahlenschätzung" => :number_range,
    "zahlenschaetzung" => :number_range,
    "numberrange" => :number_range,
    "stecknadel" => :pin_on_image,
    "pinonimage" => :pin_on_image,
    "pin" => :pin_on_image,
    "pinaufbild" => :pin_on_image,
    "bildmarkierung" => :pin_on_image
  }

  @keywords %{
    "format" => :format,
    "quiz" => :title,
    "quiztitel" => :title,
    "titel" => :title,
    "einleitung" => :intro,
    "intro" => :intro,
    "abschluss" => :outro,
    "schluss" => :outro,
    "outro" => :outro,
    "frage" => :prompt,
    "typ" => :type,
    "fragetyp" => :type,
    "beschreibung" => :description,
    "zusatz" => :description,
    "bild" => :image_hint,
    "pin" => :pin_hint,
    "stecknadel" => :pin_hint,
    "erklärung" => :explanation,
    "erklaerung" => :explanation,
    "auflösung" => :explanation,
    "aufloesung" => :explanation,
    "begründung" => :explanation,
    "begruendung" => :explanation,
    "lösung" => :solution,
    "loesung" => :solution,
    "lösungen" => :solution,
    "loesungen" => :solution,
    "antwort" => :solution,
    "richtige antwort" => :solution,
    "bereich" => :range,
    "skala" => :range,
    "toleranz" => :tolerance
  }

  # Fields a following line without a keyword continues, and how it is joined.
  @continuable %{
    title: " ",
    intro: "\n",
    outro: "\n",
    prompt: " ",
    description: "\n",
    image_hint: " ",
    pin_hint: " ",
    explanation: "\n"
  }

  @prompt_path Path.expand("../../../priv/prompts/quiz_erstellen.md", __DIR__)
  @external_resource @prompt_path
  @prompt File.read!(@prompt_path)

  @doc "The format version written by `render/2` and expected by `parse/1`."
  def version, do: @version

  @doc """
  The short prompt to hand an AI chat. It points the chat to the guide in
  `priv/prompts/ki-anleitung.md` on GitHub (so the guide only reaches chats once
  it is pushed to `main`), which has the chat interview the author and answer
  with a quiz in this format.
  """
  def prompt, do: @prompt

  @doc "The German type names used in the format, keyed by question type."
  def type_names, do: @type_names

  @doc """
  Parses quiz text.

  Returns `{:ok, %{title:, intro_text:, outro_text:, questions: [attrs], warnings: [String.t()]}}`
  where each question map holds `Question.changeset/4` attributes (without
  `:game_id`/`:position`), or `{:error, :no_questions}` when no `Frage:` line
  was found at all.
  """
  def parse(text) when is_binary(text) do
    state =
      text
      |> extract_block()
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reduce(initial_state(), fn {line, number}, state ->
        handle_line(classify(line), number, state)
      end)
      |> finish_question()

    case Enum.reverse(state.questions) do
      [] ->
        {:error, :no_questions}

      questions ->
        {title, title_warnings} = title(state.header)

        {:ok,
         %{
           title: title,
           intro_text: state.header[:intro],
           outro_text: state.header[:outro],
           questions: questions,
           warnings: title_warnings ++ Enum.reverse(state.warnings)
         }}
    end
  end

  ## Block extraction

  # Prefers the content of a Markdown code block; when a chat answer is pasted
  # whole, the quiz is the block with the most questions (the latest one on a
  # tie). An unclosed fence (a truncated answer) just has its fence line dropped.
  defp extract_block(text) do
    text = String.replace(text, ~r/\r\n?/, "\n")

    case Regex.scan(~r/^[ \t]*```[^\n]*\n(.*?)^[ \t]*```/ms, text, capture: :all_but_first) do
      [] ->
        Regex.replace(~r/^[ \t]*```.*$/m, text, "")

      blocks ->
        blocks
        |> Enum.map(&hd/1)
        |> Enum.reverse()
        |> Enum.max_by(&length(Regex.scan(~r/^\W*frage\b/imu, &1)))
    end
  end

  ## Line classification

  defp classify(line) do
    line = line |> String.replace(["**", "__"], "") |> String.trim()

    cond do
      line == "" ->
        :blank

      field = field(line) ->
        field

      match = Regex.run(~r/^[-*•–]\s+(.*)$/u, line, capture: :all_but_first) ->
        bullet(hd(match))

      match = Regex.run(~r/^(\d+)[.)]\s+(.*)$/u, line, capture: :all_but_first) ->
        [number, rest] = match
        {:numbered, String.to_integer(number), String.trim(rest)}

      true ->
        {:text, line}
    end
  end

  # `Stichwort: Wert`, also behind Markdown headings or numbering
  # (`## 3. Frage: …`) and with a number in the keyword (`Frage 3: …`).
  defp field(line) do
    line = Regex.replace(~r/^(#+\s*)?(\d+[.)]\s*)?/u, line, "")

    with [key, value] <- Regex.run(~r/^([^:]{1,30}):\s*(.*)$/u, line, capture: :all_but_first),
         normalized =
           key |> String.downcase() |> String.replace(~r/[\d#.]/u, "") |> String.trim(),
         %{^normalized => field} <- @keywords do
      {:field, field, String.trim(value)}
    else
      _ -> nil
    end
  end

  defp bullet(text) do
    case Regex.run(~r/^\[\s*([xX✓✔✅]?)\s*\]\s*(.*)$/u, text, capture: :all_but_first) do
      [mark, rest] ->
        {:bullet, mark != "", String.trim(rest)}

      nil ->
        case Regex.run(~r/^(.*?)\s*(?:\(richtig\)|✓|✔|✅)$/iu, text, capture: :all_but_first) do
          [rest] -> {:bullet, true, rest}
          nil -> {:bullet, false, String.trim(text)}
        end
    end
  end

  ## Line handling

  defp initial_state do
    %{header: %{}, questions: [], warnings: [], current: nil, last: nil, started: false}
  end

  defp handle_line(:blank, _number, state), do: %{state | last: nil}

  defp handle_line({:field, :format, value}, number, state) do
    state = %{state | started: true, last: nil}

    if String.downcase(value) == @version,
      do: state,
      else: warn(state, "Zeile #{number}: unbekanntes Format «#{value}», gelesen als #{@version}")
  end

  defp handle_line({:field, key, value}, _number, state) when key in [:title, :intro, :outro] do
    %{state | header: Map.put(state.header, key, value), started: true, last: {:header, key}}
  end

  defp handle_line({:field, :prompt, value}, number, state) do
    state = finish_question(state)
    question = %{number: length(state.questions) + 1, line: number, prompt: value, entries: []}
    %{state | current: question, started: true, last: {:question, :prompt}}
  end

  defp handle_line(line, number, %{current: nil} = state) do
    case line do
      {:text, _text} when not state.started ->
        # Chat text before the quiz starts ("Hier ist dein Quiz!").
        state

      {:text, text} ->
        continue_or_warn(state, number, text)

      _field_or_entry ->
        warn(state, "Zeile #{number}: steht vor der ersten Frage und wurde ignoriert")
    end
  end

  defp handle_line({:field, key, value}, _number, state)
       when key in [:description, :image_hint, :pin_hint, :explanation] do
    %{state | current: Map.put(state.current, key, value), last: {:question, key}}
  end

  defp handle_line({:field, :type, value}, _number, state),
    do: %{state | current: Map.put(state.current, :type, value), last: nil}

  defp handle_line({:field, key, value}, _number, state)
       when key in [:solution, :range, :tolerance] do
    entries = state.current.entries ++ [{key, value}]
    %{state | current: %{state.current | entries: entries}, last: nil}
  end

  defp handle_line({kind, _, _} = entry, _number, state) when kind in [:bullet, :numbered] do
    %{state | current: %{state.current | entries: state.current.entries ++ [entry]}, last: nil}
  end

  defp handle_line({:text, text}, number, state), do: continue_or_warn(state, number, text)

  defp continue_or_warn(%{last: nil} = state, number, text),
    do: warn(state, "Zeile #{number}: nicht verstanden und ignoriert: «#{text}»")

  defp continue_or_warn(%{last: {:header, key}} = state, _number, text),
    do: %{state | header: Map.update!(state.header, key, &join(&1, text, key))}

  defp continue_or_warn(%{last: {:question, key}} = state, _number, text),
    do: %{state | current: Map.update!(state.current, key, &join(&1, text, key))}

  defp join(existing, text, key), do: existing <> Map.fetch!(@continuable, key) <> text

  defp warn(state, message), do: %{state | warnings: [message | state.warnings]}

  defp warn_question(state, question, message),
    do: warn(state, "Frage #{question.number}: #{message}")

  defp title(%{title: title}) when title not in [nil, ""], do: {title, []}

  defp title(_header),
    do: {"Neues Quiz", ["Kein Titel gefunden («Quiz: …»), «Neues Quiz» verwendet"]}

  ## Building a question

  defp finish_question(%{current: nil} = state), do: state

  defp finish_question(%{current: question} = state) do
    {type, state} = resolve_type(question, state)
    {data, state} = build_data(type, question, state)

    attrs = %{
      type: type,
      prompt: question.prompt,
      description: description_html(question[:description]),
      solution_text: question[:explanation],
      image_hint: question[:image_hint],
      pin_hint: question[:pin_hint],
      data: data
    }

    %{state | questions: [attrs | state.questions], current: nil, last: nil}
  end

  defp resolve_type(question, state) do
    raw = question[:type]
    key = raw && raw |> String.downcase() |> String.replace(~r/[^\p{L}]/u, "")

    case Map.fetch(@type_aliases, key || "") do
      {:ok, type} ->
        {type, state}

      :error ->
        type = infer_type(question)
        name = Keyword.fetch!(@type_names, type)

        message =
          if raw in [nil, ""],
            do: "kein Typ angegeben, als «#{name}» gelesen",
            else: "Typ «#{raw}» unbekannt, als «#{name}» gelesen"

        {type, warn_question(state, question, message)}
    end
  end

  defp infer_type(question) do
    entries = question.entries
    has? = fn kind -> Enum.any?(entries, &(elem(&1, 0) == kind)) end
    bullets = for {:bullet, correct, text} <- entries, do: {correct, text}

    cond do
      question[:pin_hint] -> :pin_on_image
      has?.(:range) -> :number_range
      bullets != [] and Enum.all?(bullets, fn {_, text} -> pair(text) end) -> :matching
      Enum.count(bullets, &elem(&1, 0)) > 1 -> :multiple_choice
      bullets != [] -> :single_choice
      has?.(:numbered) -> :sequence
      true -> :text_input
    end
  end

  defp build_data(type, question, state) when type in [:single_choice, :multiple_choice] do
    solutions = for {:solution, text} <- question.entries, do: normalize(text)

    choices =
      for {kind, mark, text} <- question.entries, kind in [:bullet, :numbered], text != "" do
        # A `Lösung:` line naming a choice marks it too, for answers that list
        # the correct option separately instead of ticking it.
        %{text: text, correct: (kind == :bullet and mark) or normalize(text) in solutions}
      end

    {%{choices: choices}, state}
  end

  defp build_data(:text_input, question, state) do
    solutions = for {:solution, text} <- question.entries, text != "", do: %{text: text}

    solutions =
      if solutions == [],
        do: for({:bullet, _, text} <- question.entries, text != "", do: %{text: text}),
        else: solutions

    {%{solutions: solutions}, state}
  end

  defp build_data(:sequence, question, state) do
    entries =
      for {kind, _, _} = entry <- question.entries, kind in [:bullet, :numbered], do: entry

    entries =
      if Enum.all?(entries, &(elem(&1, 0) == :numbered)),
        do: Enum.sort_by(entries, &elem(&1, 1)),
        else: entries

    {%{items: for({_, _, text} <- entries, text != "", do: %{text: text})}, state}
  end

  defp build_data(:matching, question, state) do
    {pairs, state} =
      Enum.reduce(question.entries, {[], state}, fn
        {:bullet, _, text}, {pairs, state} ->
          case pair(text) do
            {left, right} ->
              if Enum.any?(pairs, &(normalize(&1.right_text) == normalize(right))) do
                {pairs,
                 warn_question(
                   state,
                   question,
                   "«#{right}» kommt rechts doppelt vor, Paar «#{text}» ignoriert"
                 )}
              else
                {pairs ++ [%{left_text: left, right_text: right}], state}
              end

            nil ->
              {pairs,
               warn_question(
                 state,
                 question,
                 "«#{text}» ist kein Paar (links = rechts), ignoriert"
               )}
          end

        _entry, acc ->
          acc
      end)

    {%{pairs: pairs}, state}
  end

  defp build_data(:number_range, question, state) do
    range = entry_value(question, :range)
    solution = entry_value(question, :solution)
    tolerance = entry_value(question, :tolerance)

    with {:ok, {min, max}} <- parse_range(range),
         {:ok, solution} <- parse_int(solution, "Lösung"),
         {:ok, tolerance, state} <- parse_tolerance(tolerance, question, state),
         :ok <- check_range(min, max) do
      {%{number_range: %{min: min, max: max, solution: solution, tolerance: tolerance}}, state}
    else
      {:error, message} ->
        {%{}, warn_question(state, question, message <> ", bitte im Editor ergänzen")}
    end
  end

  defp build_data(:pin_on_image, _question, state), do: {%{}, state}

  defp entry_value(question, key) do
    Enum.find_value(question.entries, fn
      {^key, value} -> value
      _ -> nil
    end)
  end

  defp pair(text) do
    case Regex.split(~r/\s*(?:=|→|->|⇒)\s*/u, text, parts: 2) do
      [left, right] when left != "" and right != "" -> {String.trim(left), String.trim(right)}
      _ -> nil
    end
  end

  ## Numbers

  defp parse_range(nil), do: {:error, "Bereich fehlt"}

  defp parse_range(text) do
    parts = Regex.split(~r/\s*(?:bis|to|–|—|\.\.)\s*|\s+-\s+|(?<=\d)-(?=-?\d)/u, text, parts: 2)

    with [min, max] <- parts,
         {:ok, min} <- parse_int(min, "Minimum"),
         {:ok, max} <- parse_int(max, "Maximum") do
      {:ok, {min, max}}
    else
      {:error, message} -> {:error, message}
      _ -> {:error, "Bereich «#{text}» nicht verstanden (erwartet: «MIN bis MAX»)"}
    end
  end

  defp parse_tolerance(nil, question, state),
    do: {:ok, 0, warn_question(state, question, "Toleranz fehlt, 0 angenommen")}

  defp parse_tolerance(text, _question, state) do
    with {:ok, tolerance} <- parse_int(text, "Toleranz"),
         do: {:ok, abs(tolerance), state}
  end

  defp check_range(min, max) when min < max, do: :ok
  defp check_range(_min, _max), do: {:error, "das Minimum muss kleiner als das Maximum sein"}

  # Whole numbers, tolerating thousands separators (5'000, 5 000, 5.000), a
  # leading ± and a trailing unit (5000 Arten). Decimals are rejected, since
  # estimation questions only hold whole numbers.
  defp parse_int(nil, label), do: {:error, "#{label} fehlt"}

  defp parse_int(text, label) do
    cleaned =
      text
      |> String.replace(~r/[\s'’`´±+]/u, "")
      |> String.replace(~r/(?<=\d)\.(?=\d{3}(?!\d))/u, "")

    case Integer.parse(cleaned) do
      {number, rest} ->
        if Regex.match?(~r/^[.,]\d/u, rest),
          do: {:error, "#{label} «#{text}» ist keine ganze Zahl"},
          else: {:ok, number}

      :error ->
        {:error, "#{label} «#{text}» ist keine Zahl"}
    end
  end

  ## Rendering

  @doc """
  Renders a game and its questions (in the given order) as quiz text.

  Media cannot be expressed in text; a question's image survives only as its
  `image_hint`. Parsing the result yields the same quiz again.
  """
  def render(%Game{} = game, questions) do
    header =
      lines([
        "Format: #{@version}",
        line("Quiz", game.title),
        line("Einleitung", game.intro_text),
        line("Abschluss", game.outro_text)
      ])

    Enum.join([header | Enum.map(questions, &render_question/1)], "\n\n") <> "\n"
  end

  defp render_question(%Question{} = question) do
    lines(
      [
        line("Frage", question.prompt || ""),
        line("Typ", Keyword.get(@type_names, question.type, "")),
        line("Beschreibung", description_text(question.description)),
        line("Bild", question.image_hint)
      ] ++
        render_data(question.type, question.data || %Data{}) ++
        [
          line("Pin", question.pin_hint),
          line("Erklärung", question.solution_text)
        ]
    )
  end

  defp render_data(type, %Data{choices: choices}) when type in [:single_choice, :multiple_choice],
    do: for(choice <- choices, do: if(choice.correct, do: "- [x] ", else: "- ") <> choice.text)

  defp render_data(:text_input, %Data{solutions: solutions}),
    do: for(solution <- solutions, do: "Lösung: " <> solution.text)

  defp render_data(:sequence, %Data{items: items}),
    do: for({item, index} <- Enum.with_index(items, 1), do: "#{index}. #{item.text}")

  defp render_data(:matching, %Data{pairs: pairs}),
    do: for(pair <- pairs, do: "- #{pair.left_text} = #{pair.right_text}")

  defp render_data(:number_range, %Data{number_range: %NumberRange{} = range}) do
    [
      range.min && range.max && "Bereich: #{range.min} bis #{range.max}",
      range.solution && "Lösung: #{range.solution}",
      range.tolerance && "Toleranz: #{range.tolerance}"
    ]
  end

  defp render_data(_type, _data), do: []

  # A blank line ends a value when parsing, so paragraphs collapse to lines.
  defp line(_key, value) when value in [nil, ""], do: nil

  defp line(key, value),
    do: "#{key}: " <> (value |> String.replace(~r/\n\s*\n/u, "\n") |> String.trim())

  defp lines(lines), do: lines |> Enum.reject(&(&1 in [nil, false])) |> Enum.join("\n")

  ## Descriptions (stored as sanitized HTML)

  defp description_html(nil), do: nil

  defp description_html(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("\n", "<br>")
  end

  defp description_text(html) when html in [nil, ""], do: nil

  defp description_text(html) do
    html
    |> String.replace(~r{<br\s*/?>|</p>\s*<p[^>]*>}iu, "\n")
    |> HtmlSanitizeEx.strip_tags()
    |> String.replace(["&lt;", "&gt;", "&quot;", "&#39;", "&#x27;", "&nbsp;"], fn
      "&lt;" -> "<"
      "&gt;" -> ">"
      "&quot;" -> "\""
      "&nbsp;" -> " "
      _apostrophe -> "'"
    end)
    |> String.replace("&amp;", "&")
    |> String.trim()
  end

  defp normalize(text), do: text |> String.trim() |> String.downcase()
end
