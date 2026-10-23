defmodule QuizWeb.PageControllerTest do
  use QuizWeb.ConnCase

  test "GET / shows the participant join landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "Beitreten"
    assert body =~ ~s(action="/join")
    assert body =~ ~s(name="code")
  end

  test "GET / links quizmasters to the login page", %{conn: conn} do
    conn = get(conn, ~p"/")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert [link] = document |> LazyHTML.query("#quizmaster-login") |> Enum.to_list()
    assert LazyHTML.attribute(link, "href") == [~p"/users/log-in"]
  end

  test "GET / leads visitors to create a quiz without an account", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert ["Denken statt" <> _] =
             document |> LazyHTML.query("h1") |> LazyHTML.text() |> String.trim() |> List.wrap()

    for id <- ["#create-quiz-cta", "#ai-cta"] do
      assert [link] = document |> LazyHTML.query(id) |> Enum.to_list()
      assert LazyHTML.attribute(link, "href") == [~p"/erstellen"]
    end
  end

  test "GET / sends visitors to the registration when the guest mode is off", %{conn: conn} do
    previous = Application.get_env(:quiz, :guest_mode)
    Application.put_env(:quiz, :guest_mode, false)
    on_exit(fn -> Application.put_env(:quiz, :guest_mode, previous) end)

    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert [link] = document |> LazyHTML.query("#create-quiz-cta") |> Enum.to_list()
    assert LazyHTML.attribute(link, "href") == [~p"/users/register"]
  end

  test "GET / offers signed-in quizmasters the AI import", %{conn: conn} do
    conn = conn |> log_in_user(Quiz.AccountsFixtures.user_fixture()) |> get(~p"/")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert [link] = document |> LazyHTML.query("#home-ai-import") |> Enum.to_list()
    assert LazyHTML.attribute(link, "href") == [~p"/erstellen"]
  end

  test "GET / disables creating for a guest at its quiz limit", %{conn: conn} do
    guest = Quiz.AccountsFixtures.guest_fixture()
    scope = Quiz.Accounts.Scope.for_user(guest)
    for _ <- 1..Quiz.Games.guest_max_games(), do: Quiz.GamesFixtures.game_fixture(scope)

    document =
      conn |> log_in_user(guest) |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    for id <- ["#home-new-quiz", "#home-ai-import"] do
      assert [card] = document |> LazyHTML.query(id) |> Enum.to_list()
      assert LazyHTML.attribute(card, "aria-disabled") == ["true"]
    end

    assert [_] = document |> LazyHTML.query("#guest-limit") |> Enum.to_list()
  end

  test "GET / warns a guest before logging out", %{conn: conn} do
    document =
      conn
      |> log_in_user(Quiz.AccountsFixtures.guest_fixture())
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert [button] = document |> LazyHTML.query("#guest-logout") |> Enum.to_list()
    assert [onclick] = LazyHTML.attribute(button, "onclick")
    assert onclick =~ "guest_logout_modal"

    assert [form] =
             document
             |> LazyHTML.query("#guest_logout_modal form[action='/users/log-out']")
             |> Enum.to_list()

    assert [_] = form |> LazyHTML.query("input[name='_method'][value='delete']") |> Enum.to_list()
  end

  test "GET / hides the login link once signed in", %{conn: conn} do
    conn = conn |> log_in_user(Quiz.AccountsFixtures.user_fixture()) |> get(~p"/")

    refute html_response(conn, 200) =~ ~s(id="quizmaster-login")
  end
end
