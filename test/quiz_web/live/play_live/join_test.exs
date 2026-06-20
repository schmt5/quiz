defmodule QuizWeb.PlayLive.JoinTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  defp open_game(_context) do
    scope = user_scope_fixture()
    %{game: game_fixture(scope, %{status: :open})}
  end

  describe "joining with feedback" do
    setup :open_game

    test "an unknown code shows a clear error naming the code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: "0000"})
        |> render_submit()

      assert html =~ "Kein Quiz mit der PIN"
      assert html =~ "0000"
    end

    test "an empty code asks for the code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: ""})
        |> render_submit()

      assert html =~ "Bitte gib die PIN ein"
    end

    test "the error clears once the participant edits the form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: "0000"})
        |> render_submit()

      assert html =~ "Kein Quiz mit der PIN"

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: "000"})
        |> render_change()

      refute html =~ "Kein Quiz mit der PIN"
    end

    test "a valid code enrols and moves to the waiting room", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      lv
      |> form("#join-form", participant: %{name: "Team A", code: game.join_code})
      |> render_submit()

      assert_redirect(lv, ~p"/play/#{game.join_code}")
    end
  end
end
