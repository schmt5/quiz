defmodule QuizWeb.GameLiveTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  @create_attrs %{status: :draft, title: "some title"}
  @update_attrs %{status: :open, title: "some updated title"}
  @invalid_attrs %{status: nil, title: nil}

  setup :register_and_log_in_user

  defp create_game(%{scope: scope}) do
    game = game_fixture(scope)

    %{game: game}
  end

  describe "Index" do
    setup [:create_game]

    test "lists all games", %{conn: conn, game: game} do
      {:ok, _index_live, html} = live(conn, ~p"/games")

      assert html =~ "Listing Games"
      assert html =~ game.title
    end

    test "saves new game", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/games")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Game")
               |> render_click()
               |> follow_redirect(conn, ~p"/games/new")

      assert render(form_live) =~ "New Game"

      assert form_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#game-form", game: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      html = render(index_live)
      assert html =~ "Game created successfully"
      assert html =~ "some title"
    end

    test "updates game in listing", %{conn: conn, game: game} do
      {:ok, index_live, _html} = live(conn, ~p"/games")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#games-#{game.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/games/#{game}/edit")

      assert render(form_live) =~ "Edit Game"

      assert form_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#game-form", game: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      html = render(index_live)
      assert html =~ "Game updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes game in listing", %{conn: conn, game: game} do
      {:ok, index_live, _html} = live(conn, ~p"/games")

      assert index_live |> element("#games-#{game.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#games-#{game.id}")
    end
  end

  describe "Show" do
    setup [:create_game]

    test "displays game", %{conn: conn, game: game} do
      {:ok, _show_live, html} = live(conn, ~p"/games/#{game}")

      assert html =~ "Quizze"
      assert html =~ "Fragen"
      assert html =~ game.title
    end

    test "a finished game links to correction and leaderboard", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :finished})
      {:ok, _show_live, html} = live(conn, ~p"/games/#{game}")

      assert html =~ ~p"/games/#{game}/correction"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end

    test "an open game shows no correction/leaderboard links yet", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})
      {:ok, _show_live, html} = live(conn, ~p"/games/#{game}")

      refute html =~ ~p"/games/#{game}/correction"
      refute html =~ ~p"/games/#{game}/leaderboard"
    end

    test "duplicates the game from the dropdown", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{title: "Original", status: :finished})

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        type: :text_input,
        prompt: "Hauptstadt von Frankreich?",
        data: %{solutions: [%{text: "Paris"}]}
      })

      {:ok, show_live, _html} = live(conn, ~p"/games/#{game}")

      assert {:ok, copy_live, html} =
               show_live
               |> element("button", "Quiz duplizieren")
               |> render_click()
               |> follow_redirect(conn)

      assert html =~ "Quiz dupliziert"
      assert html =~ "Original (Kopie)"
      # The copy carries the question over.
      assert render(copy_live) =~ "Hauptstadt von Frankreich?"
    end

    test "updates game and returns to show", %{conn: conn, game: game} do
      {:ok, show_live, _html} = live(conn, ~p"/games/#{game}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Quiz bearbeiten")
               |> render_click()
               |> follow_redirect(conn, ~p"/games/#{game}/edit?return_to=show")

      assert render(form_live) =~ "Edit Game"

      assert form_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#game-form", game: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/games/#{game}")

      html = render(show_live)
      assert html =~ "Game updated successfully"
      assert html =~ "some updated title"
    end
  end
end
