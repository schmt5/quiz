defmodule QuizWeb.DashboardAuthTest do
  # Not async: these tests swap the global :dashboard_auth config.
  use QuizWeb.ConnCase, async: false

  describe "GET /admin/dashboard" do
    test "answers 404 when no credentials are configured (prod without the secret)",
         %{conn: conn} do
      conn = get(conn, "/admin/dashboard")
      assert response(conn, 404)
    end

    test "challenges for credentials when they are configured", %{conn: conn} do
      configure_auth()

      conn = get(conn, "/admin/dashboard")

      assert response(conn, 401)
      assert [<<"Basic", _::binary>>] = get_resp_header(conn, "www-authenticate")
    end

    test "rejects wrong credentials", %{conn: conn} do
      configure_auth()

      conn =
        conn
        |> with_basic_auth("quiz", "wrong")
        |> get("/admin/dashboard")

      assert response(conn, 401)
    end

    test "lets the operator through to the dashboard with correct credentials",
         %{conn: conn} do
      configure_auth()

      conn =
        conn
        |> with_basic_auth("quiz", "s3cret")
        |> get("/admin/dashboard")

      assert redirected_to(conn) == "/admin/dashboard/home"
    end
  end

  defp configure_auth do
    Application.put_env(:quiz, :dashboard_auth, username: "quiz", password: "s3cret")
    on_exit(fn -> Application.delete_env(:quiz, :dashboard_auth) end)
  end

  defp with_basic_auth(conn, user, pass) do
    put_req_header(conn, "authorization", "Basic " <> Base.encode64("#{user}:#{pass}"))
  end
end
