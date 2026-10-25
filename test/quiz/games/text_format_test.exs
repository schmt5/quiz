defmodule Quiz.Games.TextFormatTest do
  use Quiz.DataCase, async: true

  import Quiz.AccountsFixtures

  alias Quiz.Games
  alias Quiz.Games.{Question, TextFormat}

  # The example inside the AI guide is the format's reference: it has to parse
  # cleanly, otherwise the AI is taught something the app rejects.
  defp prompt_example do
    prompt = File.read!(Application.app_dir(:quiz, "priv/prompts/ki-anleitung.md"))
    [example] = Regex.run(~r/```\n(Format:.*?)```/s, prompt, capture: :all_but_first)
    example
  end

  defp parse!(text) do
    {:ok, parsed} = TextFormat.parse(text)
    parsed
  end

  defp question(text, position \\ 1), do: Enum.at(parse!(text).questions, position - 1)

  test "the prompt links to the AI guide in this repository" do
    [path] =
      Regex.run(~r{raw\.githubusercontent\.com/schmt5/quiz/main/(\S+)}, TextFormat.prompt(),
        capture: :all_but_first
      )

    assert path == "priv/prompts/ki-anleitung.md"
    assert File.exists?(Application.app_dir(:quiz, path))
  end

  describe "parse/1 with the prompt example" do
    test "reads every question type without warnings" do
      parsed = parse!(prompt_example())

      assert parsed.warnings == []
      assert parsed.title == "Pilze der Schweiz"
      assert parsed.intro_text =~ "Willkommen"
      assert parsed.outro_text == "Danke fürs Mitspielen!"

      assert Enum.map(parsed.questions, & &1.type) == [
               :single_choice,
               :multiple_choice,
               :text_input,
               :sequence,
               :matching,
               :number_range,
               :pin_on_image
             ]
    end

    test "reads the answer data of each type" do
      [single, multiple, text, sequence, matching, range, pin] =
        parse!(prompt_example()).questions

      assert single.image_hint =~ "Knollenblätterpilz"

      assert [%{correct: false}, %{text: "Grüner Knollenblätterpilz", correct: true}, _] =
               single.data.choices

      assert single.solution_text =~ "tödlich"

      assert Enum.map(multiple.data.choices, & &1.correct) == [true, true, false]
      assert text.data.solutions == [%{text: "Fliegenpilz"}, %{text: "Amanita muscaria"}]

      assert Enum.map(sequence.data.items, & &1.text) == [
               "Schwefelkopf",
               "Steinpilz",
               "Riesenbovist"
             ]

      assert hd(matching.data.pairs) == %{left_text: "Steinpilz", right_text: "Fichtenwald"}

      assert range.data.number_range == %{min: 0, max: 10_000, solution: 5000, tolerance: 1000}

      assert pin.image_hint =~ "Umrisskarte"
      assert pin.pin_hint =~ "Unterengadin"
      assert pin.data == %{}
    end
  end

  describe "parse/1 around the quiz" do
    test "takes the quiz out of a whole pasted chat answer" do
      text = """
      Hier ist dein Quiz!

      ```
      Format: quiz-text/v1
      Quiz: Kurz

      Frage: Eins?
      Typ: Texteingabe
      Lösung: eins
      ```

      Kopiere den Block mit dem Kopieren-Knopf und füge ihn in der Quiz-App ein.
      """

      parsed = parse!(text)
      assert parsed.warnings == []
      assert parsed.title == "Kurz"
      assert [%{prompt: "Eins?"}] = parsed.questions
    end

    test "prefers the block with the most questions, the latest one on a tie" do
      text = """
      ```
      Quiz: Alt
      Frage: A?
      ```
      Geändert:
      ```
      Quiz: Neu
      Frage: A?
      ```
      ```
      Typ: nur ein Beispiel
      ```
      """

      assert parse!(text).title == "Neu"
    end

    test "reads a truncated answer whose code block was never closed" do
      text = "```\nQuiz: Abgeschnitten\nFrage: Eins?\nTyp: Texteingabe\nLösung: eins\nFrage: Zw"

      parsed = parse!(text)
      assert parsed.title == "Abgeschnitten"
      assert [%{prompt: "Eins?"}, %{prompt: "Zw"}] = parsed.questions
    end

    test "ignores chat text before the quiz, but reports stray lines inside it" do
      text = """
      Gerne, hier kommt es:
      Quiz: Test

      Frage: Eins?
      Typ: Texteingabe
      Lösung: eins

      Möchtest du noch etwas ändern?
      """

      parsed = parse!(text)
      assert parsed.title == "Test"
      assert [warning] = parsed.warnings
      assert warning =~ "Zeile 8"
      assert warning =~ "Möchtest du"
    end

    test "fails without any question" do
      assert TextFormat.parse("Quiz: Leer\nNur Text") == {:error, :no_questions}
      assert TextFormat.parse("") == {:error, :no_questions}
    end

    test "falls back to a default title" do
      parsed = parse!("Frage: Eins?\nTyp: Texteingabe\nLösung: eins")

      assert parsed.title == "Neues Quiz"
      assert [warning] = parsed.warnings
      assert warning =~ "Titel"
    end

    test "warns about an unknown format version" do
      parsed = parse!("Format: quiz-text/v9\nQuiz: X\nFrage: A?\nTyp: Texteingabe\nLösung: a")

      assert [warning] = parsed.warnings
      assert warning =~ "quiz-text/v9"
    end
  end

  describe "parse/1 tolerance" do
    test "accepts Markdown, numbering and keyword variants" do
      text = """
      **Quiz:** Varianten

      ## 1. Frage: Welche Farbe hat der Himmel?
      **Typ:** single choice
      - Grün
      - [X] Blau

      Frage 2: Welche sind Säugetiere?
      TYP: Multiple Choice
      * [x] Wal
      * [ ] Hai
      • Delfin ✓
      """

      parsed = parse!(text)
      assert parsed.warnings == []
      assert parsed.title == "Varianten"

      [first, second] = parsed.questions
      assert first.prompt == "Welche Farbe hat der Himmel?"
      assert first.type == :single_choice
      assert Enum.map(first.data.choices, & &1.correct) == [false, true]

      assert second.type == :multiple_choice

      assert Enum.map(second.data.choices, &{&1.text, &1.correct}) ==
               [{"Wal", true}, {"Hai", false}, {"Delfin", true}]
    end

    test "marks a choice named in a separate Lösung line" do
      text = "Frage: Hauptstadt?\nTyp: Einfachauswahl\n- Zürich\n- Bern\nLösung: bern"

      assert Enum.map(question(text).data.choices, & &1.correct) == [false, true]
    end

    test "infers a missing or unknown type from the content" do
      text = """
      Quiz: Typen

      Frage: Paare?
      - a = 1
      - b = 2

      Frage: Wie viel?
      Typ: Rechenaufgabe
      Bereich: 1 bis 10
      Lösung: 5
      Toleranz: 1
      """

      parsed = parse!(text)
      assert Enum.map(parsed.questions, & &1.type) == [:matching, :number_range]
      assert [missing, unknown] = parsed.warnings
      assert missing =~ "Frage 1: kein Typ"
      assert unknown =~ "Frage 2: Typ «Rechenaufgabe» unbekannt"
    end

    test "uses listed answers as text solutions" do
      text = "Frage: Pilz?\nTyp: Texteingabe\n- Fliegenpilz\n- Amanita"

      assert question(text).data.solutions == [%{text: "Fliegenpilz"}, %{text: "Amanita"}]
    end

    test "sorts a numbered sequence by its numbers" do
      text = "Frage: Ordnen\nTyp: Reihenfolge\n2. Zwei\n1. Eins\n3. Drei"

      assert Enum.map(question(text).data.items, & &1.text) == ["Eins", "Zwei", "Drei"]
    end

    test "keeps matching pairs unambiguous" do
      text = "Quiz: X\nFrage: Zuordnen\nTyp: Zuordnung\n- A -> 1\n- B → 1\n- C\n- D = 2"

      parsed = parse!(text)

      assert [%{left_text: "A", right_text: "1"}, %{left_text: "D", right_text: "2"}] =
               hd(parsed.questions).data.pairs

      assert [duplicate, not_a_pair] = parsed.warnings
      assert duplicate =~ "doppelt"
      assert not_a_pair =~ "kein Paar"
    end

    test "reads numbers with separators, signs and units" do
      text =
        "Frage: Wie viele?\nTyp: Schätzfrage\nBereich: 1'000 – 10.000\nLösung: 5 000 Arten\nToleranz: ±500"

      assert question(text).data.number_range ==
               %{min: 1000, max: 10_000, solution: 5000, tolerance: 500}

      negative = "Frage: Grad?\nTyp: Schätzfrage\nBereich: -50 bis 50\nLösung: -10\nToleranz: 5"
      assert question(negative).data.number_range.min == -50
    end

    test "assumes no tolerance when it is missing" do
      parsed = parse!("Quiz: X\nFrage: Zahl?\nTyp: Schätzfrage\nBereich: 0 bis 10\nLösung: 3")

      assert hd(parsed.questions).data.number_range.tolerance == 0
      assert [warning] = parsed.warnings
      assert warning =~ "Toleranz fehlt"
    end

    test "leaves an unusable estimate to the editor" do
      for {lines, reason} <- [
            {"Bereich: 0 bis 10\nLösung: 2,5\nToleranz: 1", "keine ganze Zahl"},
            {"Bereich: 10 bis 0\nLösung: 5\nToleranz: 1", "Minimum"},
            {"Lösung: 5\nToleranz: 1", "Bereich fehlt"},
            {"Bereich: irgendwas\nLösung: 5", "nicht verstanden"}
          ] do
        parsed = parse!("Quiz: X\nFrage: Zahl?\nTyp: Schätzfrage\n" <> lines)

        assert hd(parsed.questions).data == %{}

        assert Enum.any?(parsed.warnings, &(&1 =~ reason)),
               "no «#{reason}» in #{inspect(parsed.warnings)}"
      end
    end

    test "continues a text value on the following lines until a blank line" do
      text = """
      Quiz: X
      Frage: Lange
      Frage geht weiter?
      Typ: Texteingabe
      Lösung: ja
      Erklärung: Erste Zeile.
      Zweite Zeile.
      """

      parsed = parse!(text)
      assert parsed.warnings == []
      [question] = parsed.questions
      assert question.prompt == "Lange Frage geht weiter?"
      assert question.solution_text == "Erste Zeile.\nZweite Zeile."
    end

    test "stores a description as escaped HTML" do
      text =
        "Frage: A?\nTyp: Texteingabe\nLösung: a\nBeschreibung: <b>1 < 2</b> & so\nzweite Zeile"

      assert question(text).description == "&lt;b&gt;1 &lt; 2&lt;/b&gt; &amp; so<br>zweite Zeile"
    end
  end

  describe "import and export" do
    setup do
      %{scope: user_scope_fixture()}
    end

    test "import_game/2 creates a draft quiz with every question in order", %{scope: scope} do
      assert {:ok, game} = Games.import_game(scope, parse!(prompt_example()))

      assert game.status == :draft
      assert game.title == "Pilze der Schweiz"

      questions = Games.list_questions_for_game(scope, game)
      assert Enum.map(questions, & &1.position) == Enum.to_list(1..7)
      assert List.last(questions).pin_hint =~ "Unterengadin"

      # Everything but the pin question (which still needs its image) is playable.
      assert [%Question{type: :pin_on_image}] = Games.incomplete_questions(scope, game)
    end

    test "import_game/2 accepts whatever messy input parses", %{scope: scope} do
      text = """
      Frage: Ohne alles

      Frage: Zuordnung mit Lücken
      Typ: Zuordnung
      - A = 1
      - kaputt

      Frage: Schätzfrage kaputt
      Typ: Schätzfrage
      Bereich: 5 bis 1
      """

      assert {:ok, game} = Games.import_game(scope, parse!(text))
      assert length(Games.list_questions_for_game(scope, game)) == 3
    end

    test "render/2 and parse/1 round-trip a quiz", %{scope: scope} do
      original =
        parse!(
          prompt_example() <>
            "\nFrage: Mit Zusatz?\nTyp: Texteingabe\nBeschreibung: a & b\nzwei\nLösung: x\n"
        )

      {:ok, game} = Games.import_game(scope, original)

      text = TextFormat.render(game, Games.list_questions_for_game(scope, game))
      assert String.starts_with?(text, "Format: quiz-text/v1\nQuiz: Pilze der Schweiz\n")

      reparsed = parse!(text)
      assert reparsed.warnings == []
      assert Map.delete(reparsed, :warnings) == Map.delete(original, :warnings)
    end

    test "render/2 leaves out what text cannot hold", %{scope: scope} do
      {:ok, game} = Games.import_game(scope, parse!("Quiz: X\nFrage: Wo?\nTyp: Stecknadel"))
      [question] = Games.list_questions_for_game(scope, game)

      question = %{question | media_image_key: "uploads/1/bild.png", description: nil}

      assert TextFormat.render(game, [question]) ==
               "Format: quiz-text/v1\nQuiz: X\n\nFrage: Wo?\nTyp: Pin auf Bild\n"
    end
  end
end
