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

  describe "statistics" do
    defp answered_game(scope, opts) do
      game = game_fixture(scope, %{show_statistics: Keyword.fetch!(opts, :show_statistics)})

      question =
        question_fixture(scope, %{
          game_id: game.id,
          position: 1,
          type: :single_choice,
          prompt: "Welche Stadt?",
          data: %{choices: [%{text: "Paris", correct: true}, %{text: "Berlin", correct: false}]}
        })

      running = set_game_status(game, :running)

      for {name, idx} <- [{"t1", "1"}, {"t2", "1"}, {"t3", "0"}] do
        {:ok, p, _tok} = Quiz.Play.enroll(running, name)
        {:ok, _a} = Quiz.Play.submit_answer(running, p, question, %{"answer" => idx})
      end

      set_game_status(running, :finished)
    end

    test "stays hidden when the game has statistics disabled", %{conn: conn, scope: scope} do
      game = answered_game(scope, show_statistics: false)
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/review/1")

      refute html =~ "Statistik einblenden"
    end

    test "reveals the anonymous distribution on demand", %{conn: conn, scope: scope} do
      game = answered_game(scope, show_statistics: true)
      {:ok, lv, html} = live(conn, ~p"/games/#{game}/review/1")

      # The panel stays in the DOM but is collapsed (animated) until revealed.
      assert html =~ "Statistik einblenden"
      assert html =~ "grid-rows-[0fr]"
      assert html =~ "Verteilung der Antworten"
      # Berlin (2 votes) leads Paris (1) — most-picked first, no correctness shown.
      assert html =~ "Berlin"

      html = lv |> element("button", "Statistik einblenden") |> render_click()

      assert html =~ "grid-rows-[1fr]"
      refute html =~ "Statistik einblenden"
    end
  end
end
