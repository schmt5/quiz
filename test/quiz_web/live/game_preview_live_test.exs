defmodule QuizWeb.GameLive.PreviewTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  setup :register_and_log_in_user

  describe "Preview" do
    test "empty quiz renders the empty state", %{conn: conn, scope: scope} do
      game = game_fixture(scope)

      {:ok, _live, html} = live(conn, ~p"/games/#{game}/preview")

      assert html =~ "Noch keine Fragen in diesem Quiz."
    end

    test "renders the first question's prompt on mount", %{conn: conn, scope: scope} do
      game = game_fixture(scope)

      question_fixture(scope, %{game_id: game.id, position: 1, prompt: "First question"})
      question_fixture(scope, %{game_id: game.id, position: 2, prompt: "Second question"})

      {:ok, _live, html} = live(conn, ~p"/games/#{game}/preview")

      assert html =~ "First question"
      refute html =~ "Second question"
      assert html =~ "Senden"
    end

    test "next advances and prev returns", %{conn: conn, scope: scope} do
      game = game_fixture(scope)

      question_fixture(scope, %{game_id: game.id, position: 1, prompt: "First question"})
      question_fixture(scope, %{game_id: game.id, position: 2, prompt: "Second question"})

      {:ok, live, _html} = live(conn, ~p"/games/#{game}/preview")

      assert render(live) =~ "First question"

      live |> element(~s|button[aria-label="Nächste Frage"]|) |> render_click()
      assert render(live) =~ "Second question"

      live |> element(~s|button[aria-label="Vorherige Frage"]|) |> render_click()
      assert render(live) =~ "First question"
    end

    test "prev is disabled on the first question, next on the last", %{conn: conn, scope: scope} do
      game = game_fixture(scope)

      question_fixture(scope, %{game_id: game.id, position: 1, prompt: "First"})
      question_fixture(scope, %{game_id: game.id, position: 2, prompt: "Last"})

      {:ok, live, _html} = live(conn, ~p"/games/#{game}/preview")

      assert has_element?(live, ~s|button[aria-label="Vorherige Frage"][disabled]|)
      refute has_element?(live, ~s|button[aria-label="Nächste Frage"][disabled]|)

      live |> element(~s|button[aria-label="Nächste Frage"]|) |> render_click()

      refute has_element?(live, ~s|button[aria-label="Vorherige Frage"][disabled]|)
      assert has_element?(live, ~s|button[aria-label="Nächste Frage"][disabled]|)
    end

    test "shows shuffled sequence items for a sequence question", %{conn: conn, scope: scope} do
      game = game_fixture(scope)

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        type: :sequence,
        prompt: "Order me",
        data: %{
          items: [
            %{text: "Alpha"},
            %{text: "Bravo"},
            %{text: "Charlie"}
          ]
        }
      })

      {:ok, _live, html} = live(conn, ~p"/games/#{game}/preview")

      assert html =~ "Alpha"
      assert html =~ "Bravo"
      assert html =~ "Charlie"
    end
  end
end
