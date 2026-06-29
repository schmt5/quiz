defmodule QuizWeb.RunLive.HostTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  alias Quiz.Play

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

    test "per_question mode skips the end-of-game walkthrough link", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      game = set_game_status(game, :finished)

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Quiz beendet."
      refute html =~ "Lösungen besprechen"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end
  end

  describe "per_question review mode (running)" do
    setup %{scope: scope} do
      game =
        game_fixture(scope, %{status: :open, review_mode: :per_question, show_statistics: true})

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        type: :text_input,
        prompt: "Hauptstadt von Frankreich?"
      })

      {:ok, running} = Play.start_run(scope, game)
      %{game: running}
    end

    test "while collecting answers, offers Auswerten and hides the solution",
         %{conn: conn, game: game} do
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Auswerten"
      assert html =~ "Teams haben geantwortet"
      refute html =~ "Akzeptierte Antwort"
    end

    test "clicking Auswerten reveals the solution and the advance button",
         %{conn: conn, scope: scope, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      html = lv |> element("button", "Auswerten") |> render_click()

      # The persisted reveal flips the run into the revealing sub-phase.
      assert Quiz.Games.get_game!(scope, game.id).revealing

      # Solution is now shown; the live answer count gives way to the advance step
      # ("Quiz beenden" here, since this is the only/last question).
      assert html =~ "Akzeptierte Antwort"
      assert html =~ "Paris"
      assert html =~ "Quiz beenden"
      refute html =~ "Auswerten"
      refute html =~ "Teams haben geantwortet"
      # Stats stay behind the toggle, as on the end-review screen.
      assert html =~ "Statistik einblenden"
    end
  end
end
