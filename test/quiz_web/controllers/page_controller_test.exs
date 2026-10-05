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

  test "GET / hides the login link once signed in", %{conn: conn} do
    conn = conn |> log_in_user(Quiz.AccountsFixtures.user_fixture()) |> get(~p"/")

    refute html_response(conn, 200) =~ ~s(id="quizmaster-login")
  end
end
