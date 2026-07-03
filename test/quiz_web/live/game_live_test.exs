defmodule QuizWeb.GameLiveTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  @create_attrs %{title: "some title"}
  @update_attrs %{title: "some updated title"}
  @invalid_attrs %{title: nil}

  setup :register_and_log_in_user

  defp create_game(%{scope: scope}) do
    game = game_fixture(scope)

    %{game: game}
  end

  describe "Index" do
    setup [:create_game]

    test "lists all games", %{conn: conn, game: game} do
      {:ok, _index_live, html} = live(conn, ~p"/games")

      assert html =~ "Meine Quizze"
      assert html =~ game.title
    end

    test "saves new game", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/games")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Neues Quiz")
               |> render_click()
               |> follow_redirect(conn, ~p"/games/new")

      assert render(form_live) =~ "Neues Quiz"

      assert form_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "darf nicht leer sein"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#game-form", game: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      html = render(index_live)
      assert html =~ "Quiz erstellt."
      assert html =~ "some title"
    end

    test "updates game in listing", %{conn: conn, game: game} do
      {:ok, index_live, _html} = live(conn, ~p"/games")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#games-#{game.id} a", "Bearbeiten")
               |> render_click()
               |> follow_redirect(conn, ~p"/games/#{game}/edit")

      assert render(form_live) =~ "Quiz bearbeiten"

      assert form_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "darf nicht leer sein"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#game-form", game: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      html = render(index_live)
      assert html =~ "Quiz aktualisiert."
      assert html =~ "some updated title"
    end

    test "saves intro and outro content", %{conn: conn, scope: scope, game: game} do
      {:ok, form_live, _html} = live(conn, ~p"/games/#{game}/edit")

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#game-form",
                 game: %{
                   title: game.title,
                   intro_text: "Handys weg, pro Team eine Antwort.",
                   outro_text: "Danke fürs Mitspielen!"
                 }
               )
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      updated = Quiz.Games.get_game!(scope, game.id)
      assert updated.intro_text == "Handys weg, pro Team eine Antwort."
      assert updated.outro_text == "Danke fürs Mitspielen!"
    end

    test "uploads an intro image and removes it again", %{conn: conn, scope: scope, game: game} do
      {:ok, form_live, _html} = live(conn, ~p"/games/#{game}/edit")

      # 1×1 transparent PNG.
      png =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        )

      form_live
      |> file_input("#game-form", :intro_image, [
        %{name: "logo.png", content: png, type: "image/png"}
      ])
      |> render_upload("logo.png")

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#game-form", game: %{title: game.title})
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      updated = Quiz.Games.get_game!(scope, game.id)
      assert updated.intro_image_key =~ ~r|^uploads/.+\.png$|

      # Removing the image clears the stored key on the next save.
      {:ok, form_live, html} = live(conn, ~p"/games/#{game}/edit")
      assert html =~ "Bild entfernen"

      form_live |> element("button", "Bild entfernen") |> render_click()

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#game-form", game: %{title: game.title})
               |> render_submit()
               |> follow_redirect(conn, ~p"/games")

      assert Quiz.Games.get_game!(scope, game.id).intro_image_key == nil
    end

    test "deletes game in listing", %{conn: conn, game: game} do
      {:ok, index_live, _html} = live(conn, ~p"/games")

      assert index_live |> element("#games-#{game.id} a", "Löschen") |> render_click()
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

    test "reflects a runtime status change from the run topic without a reload",
         %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1})

      {:ok, show_live, html} = live(conn, ~p"/games/#{game}")
      # While :open there is no correction/leaderboard affordance.
      refute html =~ ~p"/games/#{game}/correction"

      # The run starts elsewhere (e.g. the host screen), broadcasting on the run
      # topic. The still-open Show page must pick it up rather than go stale.
      {:ok, _running} = Quiz.Play.start_run(scope, game)

      html = render(show_live)
      assert html =~ ~p"/games/#{game}/correction"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end

    test "duplicates the game from the dropdown", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{title: "Original"})

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        type: :text_input,
        prompt: "Hauptstadt von Frankreich?",
        data: %{solutions: [%{text: "Paris"}]}
      })

      _game = set_game_status(game, :finished)

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

      assert render(form_live) =~ "Quiz bearbeiten"

      assert form_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "darf nicht leer sein"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#game-form", game: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/games/#{game}")

      html = render(show_live)
      assert html =~ "Quiz aktualisiert."
      assert html =~ "some updated title"
    end
  end
end
