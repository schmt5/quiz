defmodule QuizWeb.GuestModeTest do
  # Changes global config (the guest switch and rate limit).
  use QuizWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures

  @quiz "Quiz: X\nFrage: A?\nTyp: Texteingabe\nLösung: a"

  defp put_env(key, value) do
    previous = Application.get_env(:quiz, key)
    Application.put_env(:quiz, key, value)
    on_exit(fn -> Application.put_env(:quiz, key, previous) end)
  end

  describe "with the guest mode switched off" do
    setup do: put_env(:guest_mode, false)

    test "visitors are sent to the login" do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/erstellen")

      conn = post(build_conn(), ~p"/erstellen", %{"import" => %{"text" => @quiz}})
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end

    test "signed-in quizmasters keep the AI import", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:ok, _lv, _html} = live(conn, ~p"/erstellen")
    end
  end

  test "caps how many guests one network creates" do
    put_env(:guest_rate_limit, {1, :timer.hours(1)})
    ip = "203.0.113.#{System.unique_integer([:positive]) |> rem(250)}"

    post_as = fn ->
      build_conn()
      |> put_req_header("fly-client-ip", ip)
      |> post(~p"/erstellen", %{"import" => %{"text" => @quiz}})
    end

    assert get_session(post_as.(), :user_token)

    conn = post_as.()
    assert redirected_to(conn) == ~p"/erstellen"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "viele Gastzugänge"
    refute get_session(conn, :user_token)
  end
end
