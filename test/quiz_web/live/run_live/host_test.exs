defmodule QuizWeb.RunLive.HostTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  setup :register_and_log_in_user

  describe "finished screen" do
    test "offers the solution walkthrough and links into it", %{conn: conn, scope: scope} do
      game = game_fixture(scope)
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      game = set_game_status(game, :finished)

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Quiz beendet."
      assert html =~ "Lösungen besprechen"
      # The walkthrough starts at the first question's position.
      assert html =~ ~p"/games/#{game}/review/1"
    end

    test "without questions, the ranking is the call-to-action", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :closed})

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Quiz beendet."
      refute html =~ "Lösungen besprechen"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end
  end
end
