defmodule QuizWeb.PageControllerTest do
  use QuizWeb.ConnCase

  test "GET / shows the participant join landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "Beitreten"
    assert body =~ ~s(action="/join")
    assert body =~ ~s(name="code")
  end
end
