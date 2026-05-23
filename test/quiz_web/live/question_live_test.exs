defmodule QuizWeb.QuestionLiveTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.GamesFixtures

  @invalid_attrs %{prompt: nil}

  @single_choice_submit_params %{
    "question" => %{
      "type" => "single_choice",
      "prompt" => "some prompt",
      "position" => "42",
      "data" => %{
        "choices_sort" => ["0", "1"],
        "choices" => %{
          "0" => %{"text" => "A", "correct" => "true"},
          "1" => %{"text" => "B", "correct" => "false"}
        }
      }
    }
  }

  @text_input_submit_params %{
    "question" => %{
      "type" => "text_input",
      "prompt" => "some updated prompt",
      "position" => "43",
      "data" => %{
        "solutions_sort" => ["0"],
        "solutions" => %{"0" => %{"text" => "Paris"}}
      }
    }
  }

  @sequence_submit_params %{
    "question" => %{
      "type" => "sequence",
      "prompt" => "some sequence prompt",
      "position" => "44",
      "data" => %{
        "items_sort" => ["0", "1", "2"],
        "items" => %{
          "0" => %{"text" => "First"},
          "1" => %{"text" => "Second"},
          "2" => %{"text" => "Third"}
        }
      }
    }
  }

  setup :register_and_log_in_user

  defp create_game(%{scope: scope}) do
    %{game: game_fixture(scope)}
  end

  defp create_game_and_question(%{scope: scope}) do
    game = game_fixture(scope)
    question = question_fixture(scope, %{game_id: game.id})
    %{game: game, question: question}
  end

  describe "Index — empty quiz" do
    setup [:create_game]

    test "shows the empty-state sidebar card and the type picker", %{conn: conn, game: game} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions")

      assert html =~ "Fragen"
      assert html =~ "Noch keine Fragen"
      assert html =~ "Welche Art von Frage möchtest du hinzufügen?"
      assert html =~ "Single-Choice"
      assert html =~ "Texteingabe"
      assert html =~ "Reihenfolge"
    end
  end

  describe "Index — listing" do
    setup [:create_game_and_question]

    test "lists existing questions in the sidebar", %{conn: conn, game: game, question: question} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions")

      assert html =~ question.prompt
      # type picker should still be visible when no selection
      assert html =~ "Welche Art von Frage möchtest du hinzufügen?"
    end

    test "patching to /edit shows the form for that question", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")

      live
      |> element(~s|#questions-#{question.id} a|)
      |> render_click()

      assert_patched(live, ~p"/games/#{game}/questions/#{question}/edit")
      assert render(live) =~ "Bearbeiten"
      assert render(live) =~ "Single-Choice"
    end
  end

  describe "Creating a question" do
    setup [:create_game]

    test "redirects to type picker when no type is provided", %{conn: conn, game: game} do
      assert {:error, {:live_redirect, %{to: target}}} =
               live(conn, ~p"/games/#{game}/questions/new")

      assert target == ~p"/games/#{game}/questions"

      {:ok, _live, html} = live(conn, target)
      assert html =~ "Welche Art von Frage möchtest du hinzufügen?"
    end

    test "shows a single-choice form with the type fixed", %{conn: conn, game: game} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/new?type=single_choice")

      assert html =~ "Neue Frage"
      assert html =~ "Single-Choice"
      # The type select must not be present anymore
      refute html =~ ~s|name="question[type]" type="select"|
      refute html =~ ~s|<select id="question_type"|
      assert html =~ ~s|name="question[type]"|
    end

    test "saves a new single-choice question and lands on its edit form", %{
      conn: conn,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/new?type=single_choice")

      assert live
             |> form("#question-form", question: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      render_submit(live, "save", @single_choice_submit_params)

      html = render(live)
      assert html =~ "Frage erfolgreich erstellt"
      assert html =~ "some prompt"
      assert html =~ "Bearbeiten"
    end

    test "saves a new text_input question via the Text card", %{conn: conn, game: game} do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/new?type=text_input")

      render_submit(live, "save", @text_input_submit_params)

      html = render(live)
      assert html =~ "Frage erfolgreich erstellt"
      assert html =~ "some updated prompt"
    end

    test "saves a new sequence question via the Reihenfolge card", %{conn: conn, game: game} do
      {:ok, live, html} = live(conn, ~p"/games/#{game}/questions/new?type=sequence")

      assert html =~ "Reihenfolge"
      assert html =~ "Die Reihenfolge ist die Lösung"

      render_submit(live, "save", @sequence_submit_params)

      html = render(live)
      assert html =~ "Frage erfolgreich erstellt"
      assert html =~ "some sequence prompt"
      assert html =~ "First"
      assert html =~ "Second"
      assert html =~ "Third"
    end
  end

  describe "Editing a question" do
    setup [:create_game_and_question]

    test "renders the form pre-filled", %{conn: conn, game: game, question: question} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert html =~ "Bearbeiten"
      assert html =~ question.prompt
    end

    test "validates and saves changes", %{conn: conn, game: game, question: question} do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert live
             |> form("#question-form", question: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      params =
        put_in(@single_choice_submit_params, ["question", "prompt"], "renamed prompt")

      render_submit(live, "save", params)

      html = render(live)
      assert html =~ "Frage erfolgreich aktualisiert"
      assert html =~ "renamed prompt"
    end

    test "deletes the current question and returns to the type picker", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      live |> element(~s|a[aria-label="Frage löschen"]|) |> render_click()

      assert_patched(live, ~p"/games/#{game}/questions")
      html = render(live)
      assert html =~ "Welche Art von Frage möchtest du hinzufügen?"
      assert html =~ "Noch keine Fragen"
    end
  end

  describe "Reorder" do
    setup %{scope: scope} do
      game = game_fixture(scope)

      q1 =
        question_fixture(scope, %{game_id: game.id, position: 1, prompt: "First question"})

      q2 =
        question_fixture(scope, %{game_id: game.id, position: 2, prompt: "Second question"})

      q3 =
        question_fixture(scope, %{game_id: game.id, position: 3, prompt: "Third question"})

      %{game: game, q1: q1, q2: q2, q3: q3}
    end

    test "reorder icon button only shows when there are 2+ questions", %{conn: conn, scope: scope} do
      empty_game = game_fixture(scope)
      {:ok, _live, html} = live(conn, ~p"/games/#{empty_game}/questions")
      refute html =~ "Fragen sortieren"

      one_game = game_fixture(scope)
      question_fixture(scope, %{game_id: one_game.id, position: 1})
      {:ok, _live, html} = live(conn, ~p"/games/#{one_game}/questions")
      refute html =~ "Fragen sortieren"
    end

    test "shows the reorder icon button when there are multiple questions", %{
      conn: conn,
      game: game
    } do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions")
      assert html =~ "Fragen sortieren"
      assert html =~ ~p"/games/#{game}/questions/reorder"
    end

    test "lists questions in current order on the reorder page", %{
      conn: conn,
      game: game,
      q1: q1,
      q2: q2,
      q3: q3
    } do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/reorder")

      assert html =~ "Fragen sortieren"
      assert html =~ q1.prompt
      assert html =~ q2.prompt
      assert html =~ q3.prompt

      [_, first, second, third] = String.split(html, ~r/id="questions-\d+"/, parts: 4)
      assert first =~ q1.prompt
      assert second =~ q2.prompt
      assert third =~ q3.prompt
    end

    test "reorder event + save persists new positions and redirects", %{
      conn: conn,
      scope: scope,
      game: game,
      q1: q1,
      q2: q2,
      q3: q3
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/reorder")

      render_hook(live, "reorder", %{
        "ids" => [Integer.to_string(q3.id), Integer.to_string(q1.id), Integer.to_string(q2.id)]
      })

      result = live |> element("button", "Reihenfolge speichern") |> render_click()
      assert {:error, {:live_redirect, %{to: target}}} = result
      assert target == ~p"/games/#{game}/questions"

      positions =
        Quiz.Games.list_questions_for_game(scope, game)
        |> Enum.map(&{&1.id, &1.position})
        |> Map.new()

      assert positions[q3.id] == 1
      assert positions[q1.id] == 2
      assert positions[q2.id] == 3
    end

    test "save without reordering keeps the existing positions", %{
      conn: conn,
      scope: scope,
      game: game,
      q1: q1,
      q2: q2,
      q3: q3
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/reorder")

      live |> element("button", "Reihenfolge speichern") |> render_click()

      positions =
        Quiz.Games.list_questions_for_game(scope, game)
        |> Enum.map(&{&1.id, &1.position})
        |> Map.new()

      assert positions[q1.id] == 1
      assert positions[q2.id] == 2
      assert positions[q3.id] == 3
    end
  end
end
