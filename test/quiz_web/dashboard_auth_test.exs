defmodule QuizWeb.DashboardAuthTest do
  use QuizWeb.ConnCase, async: true

  import Quiz.AccountsFixtures

  describe "GET /admin/dashboard" do
    test "redirects anonymous visitors to the login", %{conn: conn} do
      conn = get(conn, "/admin/dashboard")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "turns away logged-in users without the admin flag", %{conn: conn} do
      conn =
        conn
        |> log_in_user(user_fixture())
        |> get("/admin/dashboard")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Administratoren"
    end

    test "lets admins through to the dashboard", %{conn: conn} do
      {:ok, admin} = Quiz.Accounts.set_admin(user_fixture(), true)

      conn =
        conn
        |> log_in_user(admin)
        |> get("/admin/dashboard")

      assert redirected_to(conn) == "/admin/dashboard/home"
    end
  end
end
