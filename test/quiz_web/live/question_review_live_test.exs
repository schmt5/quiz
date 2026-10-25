defmodule QuizWeb.QuestionReviewLiveTest do
  use QuizWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quiz.Games
  alias Quiz.Games.TextFormat

  @quiz """
  Format: quiz-text/v1
  Quiz: Pilze

  Frage: Welcher Pilz ist giftig?
  Typ: Single-Choice
  - Steinpilz
  - [x] Fliegenpilz
  Erklärung: Er enthält Ibotensäure.

  Frage: Wie heisst der Pilz mit rotem Hut?
  Typ: Texteingabe
  Lösung: Fliegenpilz

  Frage: Wo liegt der Nationalpark?
  Typ: Pin auf Bild
  Bild: Karte der Schweiz
  Pin: im Unterengadin
  """

  setup :register_and_log_in_user

  setup %{scope: scope} do
    {:ok, parsed} = TextFormat.parse(@quiz)

    {:ok, game} =
      Games.import_game(scope, parsed, %{review_mode: :per_question, show_statistics: true})

    %{game: game}
  end

  test "shows one question at a time, with its solution", %{conn: conn, game: game} do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht")

    assert has_element?(lv, "#wizard-steps [aria-current='step']", "Fragen prüfen")
    assert has_element?(lv, "#review-progress", "Frage 1 von 3")
    assert has_element?(lv, "#review-question", "Welcher Pilz ist giftig?")
    refute has_element?(lv, "#review-question", "Wie heisst der Pilz")
    assert has_element?(lv, "#review-solution", "Ibotensäure")
    assert has_element?(lv, "#review-accept")
    assert has_element?(lv, "#review-edit")
    assert has_element?(lv, "#review-discard")
  end

  test "accepting moves on to the next question", %{conn: conn, game: game} do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht")

    lv |> element("#review-accept") |> render_click()

    assert_patch(lv, ~p"/games/#{game}/durchsicht?frage=2")
    assert has_element?(lv, "#review-progress", "Frage 2 von 3")
    assert has_element?(lv, "#review-question", "Wie heisst der Pilz")
  end

  test "discarding deletes the question and shows the next one", %{
    conn: conn,
    scope: scope,
    game: game
  } do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht")

    lv |> element("#review-discard") |> render_click()

    assert_patch(lv, ~p"/games/#{game}/durchsicht?frage=1")
    assert has_element?(lv, "#review-progress", "Frage 1 von 2")
    assert has_element?(lv, "#review-question", "Wie heisst der Pilz")
    assert length(Games.list_questions_for_game(scope, game)) == 2
  end

  test "adjusting opens the question form in place", %{conn: conn, scope: scope, game: game} do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht")

    lv |> element("#review-edit") |> render_click()
    assert has_element?(lv, "#question-form")
    refute has_element?(lv, "#review-accept")

    lv
    |> form("#question-form", question: %{prompt: "Welcher Pilz ist tödlich?"})
    |> render_change()

    lv |> element("#review-done") |> render_click()

    assert has_element?(lv, "#review-question", "Welcher Pilz ist tödlich?")

    assert [%{prompt: "Welcher Pilz ist tödlich?"} | _] =
             Games.list_questions_for_game(scope, game)
  end

  test "a pin question asks for its image", %{conn: conn, game: game} do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht?frage=3")

    assert has_element?(lv, "#review-image-missing", "Karte der Schweiz")
    assert has_element?(lv, "#review-image-missing", "im Unterengadin")
    refute has_element?(lv, "#review-solution")

    lv |> element("#review-upload-image") |> render_click()
    assert has_element?(lv, "#question-form")
  end

  test "after the last question come the settings", %{conn: conn, game: game} do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht?frage=3")

    lv |> element("#review-accept") |> render_click()
    assert_patch(lv, ~p"/games/#{game}/durchsicht?frage=4")
    assert_patch(lv, ~p"/games/#{game}/durchsicht?ablauf")

    assert has_element?(lv, "#wizard-steps [aria-current='step']", "Ablauf")
    assert has_element?(lv, "#review-mode-per-question[checked]")
    assert has_element?(lv, "#show-statistics[checked]")
  end

  test "saving the settings opens the quiz in «Ansehen» without a notice", %{
    conn: conn,
    scope: scope,
    game: game
  } do
    {:ok, lv, _html} = live(conn, ~p"/games/#{game}/durchsicht?ablauf")

    {:ok, view, html} =
      lv
      |> form("#settings-form", settings: %{review_mode: "end", show_statistics: "false"})
      |> render_submit()
      |> follow_redirect(conn, ~p"/games/#{game}/questions")

    assert has_element?(view, "[id^='view-question-']")
    refute html =~ "flash-info"

    game = Games.get_game!(scope, game.id)
    assert game.review_mode == :end
    refute game.show_statistics
  end
end
