defmodule QuizWeb.CorrectionLiveTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  alias Quiz.Play

  setup :register_and_log_in_user

  defp running_game_with_answers(%{scope: scope}) do
    game = game_fixture(scope, %{status: :running})

    question =
      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        type: :text_input,
        prompt: "Hauptstadt von Frankreich?",
        data: %{solutions: [%{text: "Paris"}]}
      })

    {:ok, a, _} = Play.enroll(game, "Team A")
    {:ok, b, _} = Play.enroll(game, "Team B")
    {:ok, c, _} = Play.enroll(game, "Team C")

    Play.submit_answer(game, a, question, %{"answer" => "Paris"})
    Play.submit_answer(game, b, question, %{"answer" => "paris"})
    Play.submit_answer(game, c, question, %{"answer" => "Berlin"})

    %{game: game, question: question, teams: %{a: a, b: b, c: c}}
  end

  describe "overview" do
    setup :running_game_with_answers

    test "lists the question and links into it", %{conn: conn, game: game} do
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/correction")

      assert html =~ "Korrektur"
      assert html =~ "Hauptstadt von Frankreich?"
      assert html =~ ~p"/games/#{game}/correction/1"
    end
  end

  describe "grading a question" do
    setup :running_game_with_answers

    test "shows grouped answers with the auto verdict", %{conn: conn, game: game} do
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/correction/1")

      # Paris bucket (2 teams) and Berlin bucket (1) are shown.
      assert html =~ "Paris"
      assert html =~ "Berlin"
      assert html =~ "2×"
    end

    test "grading a group applies to every team in it", %{conn: conn, game: game, teams: teams} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/correction/1")

      # Group 0 is the most common bucket: "Paris" (Team A + Team B).
      lv
      |> element("button[phx-value-index='0'][phx-value-grade='half']")
      |> render_click()

      q = question(game, 1)
      assert Play.get_answer(teams.a, q).grade == :half
      assert Play.get_answer(teams.b, q).grade == :half
      # Team C (Berlin) is a different group, untouched.
      assert Play.get_answer(teams.c, q).grade == :zero
    end

    test "Fertig marks the question done", %{conn: conn, game: game, question: question} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/correction/1")

      lv |> element("button", "Fertig") |> render_click()

      assert Play.correction_done?(question)
    end
  end

  describe "leaderboard" do
    setup :running_game_with_answers

    test "shows a placeholder until grading is published", %{conn: conn, game: game} do
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/leaderboard")
      assert html =~ "Korrektur in Bearbeitung"
      refute html =~ "Team A"
    end

    test "reveals standings after publishing", %{conn: conn, scope: scope, game: game} do
      {:ok, _game} = Play.publish_grading(scope, game)

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/leaderboard")
      assert html =~ "Team A"
      assert html =~ "Team C"
      refute html =~ "Korrektur in Bearbeitung"
    end
  end

  defp question(game, position), do: Play.get_question(game, position)
end
