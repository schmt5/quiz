defmodule QuizWeb.RunLive.ReviewTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  setup :register_and_log_in_user

  defp game_with_questions(%{scope: scope}) do
    game = game_fixture(scope)

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

    %{game: set_game_status(game, :finished)}
  end

  describe "walkthrough" do
    setup :game_with_questions

    test "shows the question and its solution at the given position", %{conn: conn, game: game} do
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/review/1")

      assert html =~ "Frage 1 / 2"
      assert html =~ "Welche Stadt?"
      assert html =~ "Paris"
      assert html =~ "Berlin"
    end

    test "the URL carries the position, so navigation is reload-safe", %{conn: conn, game: game} do
      # Land directly on the second question (as a refresh / reconnect would).
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/review/2")

      assert html =~ "Frage 2 / 2"
      assert html =~ "Hauptstadt von Frankreich?"
      assert html =~ "Akzeptierte Antwort"
    end

    test "Weiter points to the next question", %{conn: conn, game: game} do
      {:ok, lv, html} = live(conn, ~p"/games/#{game}/review/1")

      assert html =~ "Weiter"
      assert lv |> element("a", "Weiter") |> render() =~ ~p"/games/#{game}/review/2"
    end

    test "first question disables Zurück", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/review/1")
      assert lv |> element(".btn-disabled", "Zurück") |> has_element?()
    end

    test "last question replaces Weiter with the ranking call-to-action", %{conn: conn, game: game} do
      {:ok, lv, html} = live(conn, ~p"/games/#{game}/review/2")

      refute html =~ "Weiter"
      assert lv |> element("a", "Zur Rangliste") |> has_element?()
      assert html =~ ~p"/games/#{game}/leaderboard"
    end

    test "an unknown position bounces to the first question", %{conn: conn, game: game} do
      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/games/#{game}/review/99")
      assert to == ~p"/games/#{game}/review/1"
    end
  end

  test "a game without questions bounces back to the run screen", %{conn: conn, scope: scope} do
    game = game_fixture(scope, %{status: :finished})

    assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/games/#{game}/review/1")
    assert to == ~p"/games/#{game}/run"
  end

  describe "every question type renders" do
    test "sequence, matching and pin solutions render without crashing", %{conn: conn, scope: scope} do
      game = game_fixture(scope)
      question_fixture(scope, %{game_id: game.id, position: 1, type: :sequence})
      question_fixture(scope, %{game_id: game.id, position: 2, type: :matching})
      question_fixture(scope, %{game_id: game.id, position: 3, type: :pin_on_image})
      game = set_game_status(game, :finished)

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/review/1")
      assert html =~ "First"

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/review/2")
      assert html =~ "France"
      assert html =~ "Paris"

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/review/3")
      assert html =~ "uploads/test/fixture.png"
    end
  end
end
