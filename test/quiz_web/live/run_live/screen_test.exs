defmodule QuizWeb.RunLive.ScreenTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  alias Quiz.Play

  setup :register_and_log_in_user

  defp game_with_questions(%{scope: scope}) do
    game =
      game_fixture(scope, %{status: :open, review_mode: :per_question, show_statistics: true})

    question_fixture(scope, %{
      game_id: game.id,
      position: 1,
      type: :single_choice,
      prompt: "Welche Stadt?",
      data: %{choices: [%{text: "Paris", correct: true}, %{text: "Berlin", correct: false}]}
    })

    question_fixture(scope, %{
      game_id: game.id,
      position: 2,
      type: :text_input,
      prompt: "Hauptstadt von Frankreich?",
      data: %{solutions: [%{text: "Paris"}]}
    })

    %{game: game}
  end

  describe "lobby" do
    setup :game_with_questions

    test "shows the joined teams without any operator controls", %{conn: conn, game: game} do
      {:ok, _participant, _token} = Play.enroll(game, "Team A")
      {:ok, screen, _html} = live(conn, ~p"/games/#{game}/screen")

      assert render(screen) =~ "Team A"
      refute has_element?(screen, ~s|button[phx-click="start"]|)
      refute has_element?(screen, ~s|button[phx-click="remove_participant"]|)
    end

    test "a team joining shows up live", %{conn: conn, game: game} do
      {:ok, screen, _html} = live(conn, ~p"/games/#{game}/screen")

      {:ok, participant, _token} = Play.enroll(game, "Team B")

      assert has_element?(screen, "#participant-#{participant.id}")
    end
  end

  describe "following the host through the run" do
    setup :game_with_questions

    test "shows the question the host is on, then its solution and statistics",
         %{conn: conn, scope: scope, game: game} do
      {:ok, running} = Play.start_run(scope, game)
      {:ok, screen, html} = live(conn, ~p"/games/#{running}/screen")
      {:ok, host, _html} = live(conn, ~p"/games/#{running}/run")

      assert html =~ "Welche Stadt?"
      assert html =~ "Frage 1 / 2"
      assert has_element?(screen, "#answered-count")

      host |> element("#reveal") |> render_click()
      refute has_element?(screen, "#answered-count")
      assert has_element?(screen, ~s|#stats-panel[class*="grid-rows-[0fr]"]|)
      refute has_element?(screen, "#show-stats")

      host |> element("#show-stats") |> render_click()
      assert has_element?(screen, ~s|#stats-panel[class*="grid-rows-[1fr]"]|)

      host |> element("#advance") |> render_click()
      html = render(screen)
      assert html =~ "Hauptstadt von Frankreich?"
      assert html =~ "Frage 2 / 2"
      # The next question starts with the statistics collapsed again.
      refute Quiz.Games.get_game!(scope, game.id).screen_show_stats
    end

    test "follows the walkthrough and the leaderboard after the quiz",
         %{conn: conn, scope: scope, game: game} do
      {:ok, participant, _token} = Play.enroll(game, "Team A")
      game = set_game_status(game, :finished)
      {:ok, screen, _html} = live(conn, ~p"/games/#{game}/screen")

      assert has_element?(screen, "#finished-stage")

      {:ok, _review, _html} = live(conn, ~p"/games/#{game}/review/2")
      html = render(screen)
      assert html =~ "Lösung · Frage 2 / 2"
      assert html =~ "Hauptstadt von Frankreich?"

      # A reloaded projector lands on the same question.
      {:ok, _reloaded, html} = live(conn, ~p"/games/#{game}/screen")
      assert html =~ "Lösung · Frage 2 / 2"

      {:ok, _leaderboard, _html} = live(conn, ~p"/games/#{game}/leaderboard")
      assert has_element?(screen, "#screen-leaderboard")
      assert render(screen) =~ "Korrektur in Bearbeitung"

      {:ok, _} = Play.publish_grading(scope, Quiz.Games.get_game!(scope, game.id))
      html = render(screen)
      refute html =~ "Korrektur in Bearbeitung"
      assert html =~ participant.name
    end

    test "returns to the closing screen when the host leaves the walkthrough",
         %{conn: conn, game: game} do
      game = set_game_status(game, :finished)
      {:ok, screen, _html} = live(conn, ~p"/games/#{game}/screen")
      {:ok, _review, _html} = live(conn, ~p"/games/#{game}/review/1")
      refute has_element?(screen, "#finished-stage")

      {:ok, _host, _html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(screen, "#finished-stage")
    end
  end

  test "another user's game is not reachable", %{conn: conn} do
    other = game_fixture(user_scope_fixture())

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/games/#{other}/screen") end
  end
end
