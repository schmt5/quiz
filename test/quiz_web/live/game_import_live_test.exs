defmodule QuizWeb.GameImportLiveTest do
  use QuizWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quiz.Games

  @quiz """
  Hier ist dein Quiz:

  ```
  Format: quiz-text/v1
  Quiz: Pilze

  Frage: Welcher Pilz ist giftig?
  Typ: Single-Choice
  Bild: Foto eines Fliegenpilzes
  - Steinpilz
  - [x] Fliegenpilz
  Erklärung: Er enthält Ibotensäure.

  Frage: Wo liegt der Nationalpark?
  Typ: Pin auf Bild
  Bild: Karte der Schweiz
  Pin: im Unterengadin
  ```
  """

  setup :register_and_log_in_user

  test "the games list links to the import", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/games")

    assert has_element?(lv, "#import-quiz[href='/erstellen']")
  end

  test "starts with the prompt to copy, one step at a time", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/erstellen")

    assert has_element?(lv, "#wizard-steps [aria-current='step']", "Prompt kopieren")
    assert has_element?(lv, "#copy-prompt[data-copy-from='ai-prompt']")
    assert lv |> element("#ai-prompt") |> render() =~ "raw.githubusercontent.com"
    refute has_element?(lv, "#open-chatgpt")
    refute has_element?(lv, "#open-claude")
    refute has_element?(lv, "#import-form")

    lv |> element("#step-next") |> render_click()
    assert_patch(lv, ~p"/erstellen?schritt=2")
    assert has_element?(lv, "#ai-step-chat")

    lv |> element("#step-next") |> render_click()
    assert_patch(lv, ~p"/erstellen?schritt=3")
    assert has_element?(lv, "#import-form")
    assert has_element?(lv, "#create-quiz[disabled]")
  end

  test "keeps the step in the URL", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")
    assert has_element?(lv, "#import-form")

    {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=9")
    assert has_element?(lv, "#ai-step-prompt")
  end

  test "recognises pasted text", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")

    lv |> form("#import-form", import: %{text: @quiz}) |> render_change()

    assert has_element?(lv, "#preview-title", "Pilze")
    assert has_element?(lv, "#preview-count", "2 Fragen")
    refute has_element?(lv, "#preview-warnings")
    refute has_element?(lv, "#create-quiz[disabled]")
  end

  test "shows parser warnings with a copyable note for the AI", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")

    text = "Quiz: X\nFrage: Zahl?\nTyp: Rechenaufgabe\nBereich: 0 bis 10\nLösung: 3\nToleranz: 1"
    lv |> form("#import-form", import: %{text: text}) |> render_change()

    assert has_element?(lv, "#preview-warnings", "Rechenaufgabe")
    assert has_element?(lv, "#copy-feedback[data-copy-from='ai-feedback']")
    assert lv |> element("#ai-feedback") |> render() =~ "gib das ganze Quiz nochmals"
  end

  test "explains when no question was found", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")

    lv |> form("#import-form", import: %{text: "Klar, ich helfe dir gern!"}) |> render_change()

    assert has_element?(lv, "#preview-error")
    assert has_element?(lv, "#create-quiz[disabled]")
  end

  test "creates a draft quiz and opens the review", %{conn: conn, scope: scope} do
    {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")

    lv |> form("#import-form", import: %{text: @quiz}) |> render_submit()

    [game] = Games.list_games(scope)
    assert_redirect(lv, ~p"/games/#{game}/durchsicht")
    assert game.title == "Pilze"
    assert game.status == :draft
    assert game.review_mode == :per_question
    assert game.show_statistics

    assert [
             %{type: :single_choice, image_hint: "Foto eines Fliegenpilzes"},
             %{pin_hint: "im Unterengadin"}
           ] =
             Games.list_questions_for_game(scope, game)
  end

  describe "without an account" do
    test "visitors can use it and learn about the guest access" do
      {:ok, lv, _html} = live(build_conn(), ~p"/erstellen?schritt=3")

      assert has_element?(lv, "#guest-notice", "Gastzugang")
      assert has_element?(lv, "#import-form[action='/erstellen']")
    end

    test "creating signs the visitor in as a guest owning the new quiz" do
      conn = build_conn()
      {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")

      form = form(lv, "#import-form", import: %{text: @quiz})
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert "/games/" <> rest = redirected_to(conn)
      assert rest =~ ~r{^\d+/durchsicht$}
      refute Phoenix.Flash.get(conn.assigns.flash, :info)

      {user, _} = Quiz.Accounts.get_user_by_session_token(get_session(conn, :user_token))
      assert user.guest
      assert [%{title: "Pilze"}] = Games.list_games(Quiz.Accounts.Scope.for_user(user))
    end
  end

  describe "as a guest" do
    setup do
      guest = Quiz.AccountsFixtures.guest_fixture()
      %{conn: log_in_user(build_conn(), guest), guest_scope: Quiz.Accounts.Scope.for_user(guest)}
    end

    test "imports directly into the guest account", %{conn: conn, guest_scope: scope} do
      {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")
      assert has_element?(lv, "#guest-notice", "als Gast")

      lv |> form("#import-form", import: %{text: @quiz}) |> render_submit()

      assert [_] = Games.list_games(scope)
    end

    test "points to registration at the quiz limit", %{conn: conn, guest_scope: scope} do
      for _ <- 1..Games.guest_max_games(), do: Quiz.GamesFixtures.game_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/erstellen?schritt=3")
      lv |> form("#import-form", import: %{text: @quiz}) |> render_change()

      assert has_element?(lv, "#guest-limit a[href='/users/register']")
      assert has_element?(lv, "#create-quiz[disabled]")
    end
  end
end
