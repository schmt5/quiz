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

  test "GET / hides the login link once signed in", %{conn: conn} do
    conn = conn |> log_in_user(Quiz.AccountsFixtures.user_fixture()) |> get(~p"/")

    refute html_response(conn, 200) =~ ~s(id="quizmaster-login")
  end
end
