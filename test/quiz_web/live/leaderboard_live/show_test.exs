defmodule QuizWeb.LeaderboardLive.ShowTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  setup :register_and_log_in_user

  describe "outro modal" do
    test "offers the outro modal when outro content exists", %{conn: conn, scope: scope} do
      game =
        game_fixture(scope, %{
          status: :finished,
          outro_text: "Danke und bis zum nächsten Mal!",
          outro_image_key: "uploads/1/sponsor.png"
        })

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/leaderboard")

      assert html =~ "Abschluss &amp; Infos"
      assert html =~ "Danke und bis zum nächsten Mal!"
      assert html =~ Quiz.Storage.url("uploads/1/sponsor.png")
      assert html =~ ~s|id="outro_modal"|
    end

    test "shows no outro button without outro content", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :finished})

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/leaderboard")

      refute html =~ "outro_modal"
      refute html =~ "Abschluss &amp; Infos"
    end
  end
end
