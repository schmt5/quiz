defmodule QuizWeb.DashboardAuthTest do
  use QuizWeb.ConnCase, async: true

  import Quiz.AccountsFixtures

  describe "GET /admin/dashboard" do
    test "redirects anonymous visitors to the login", %{conn: conn} do
      conn = get(conn, "/admin/dashboard")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "lets a logged-in quiz master through to the dashboard", %{conn: conn} do
      conn =
        conn
        |> log_in_user(user_fixture())
        |> get("/admin/dashboard")

      assert redirected_to(conn) == "/admin/dashboard/home"
    end
  end
end
