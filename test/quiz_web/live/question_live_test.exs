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

  @pin_submit_params %{
    "question" => %{
      "type" => "pin_on_image",
      "prompt" => "Wo liegt Paris?",
      "position" => "45",
      "data" => %{
        "pin" => %{
          "image_key" => "",
          "target_x" => "0.5",
          "target_y" => "0.5",
          "radius" => "0.1"
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
      assert html =~ "Pin auf Bild"
    end
  end

  describe "Index — listing" do
    setup [:create_game_and_question]

    test "lists existing questions in the sidebar", %{conn: conn, game: game, question: question} do
      {:ok, live, html} = live(conn, ~p"/games/#{game}/questions")

      assert html =~ question.prompt
      # «Ansehen» is the default: the questions themselves, no type picker.
      assert has_element?(live, "#view-question-#{question.id}")
      refute html =~ "Welche Art von Frage möchtest du hinzufügen?"
    end

    test "opens an empty quiz on the type picker", %{conn: conn, scope: scope} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game_fixture(scope)}/questions")

      assert html =~ "Welche Art von Frage möchtest du hinzufügen?"
    end

    test "a link to one question opens its form", %{conn: conn, game: game, question: question} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert html =~ "Antwortoptionen"
    end

    test "patching to /edit shows the form for that question", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-mode="edit"]|) |> render_click()

      live
      |> element(~s|#questions-#{question.id} a|)
      |> render_click()

      assert_patched(live, ~p"/games/#{game}/questions/#{question}/edit")
      assert render(live) =~ "Bearbeiten"
      assert render(live) =~ "Antwortoptionen"
    end
  end

  describe "Index — view mode (Ansehen)" do
    setup %{scope: scope} do
      game = game_fixture(scope)
      q1 = question_fixture(scope, %{game_id: game.id, position: 1, prompt: "Erste Frage"})
      q2 = question_fixture(scope, %{game_id: game.id, position: 2, prompt: "Zweite Frage"})
      %{game: game, q1: q1, q2: q2}
    end

    test "toggling to Ansehen renders the participant view of all questions", %{
      conn: conn,
      game: game,
      q1: q1,
      q2: q2
    } do
      {:ok, live, view_html} = live(conn, ~p"/games/#{game}/questions")

      # «Ansehen» by default: every question's prompt rendered participant-style.
      refute view_html =~ "Welche Art von Frage möchtest du hinzufügen?"
      assert view_html =~ q1.prompt
      assert view_html =~ q2.prompt
      # single_choice fixture renders selectable radio inputs.
      assert view_html =~ ~s|type="radio"|

      # «Bearbeiten» shows the type picker instead.
      edit_html = live |> element(~s|button[phx-value-mode="edit"]|) |> render_click()
      assert edit_html =~ "Welche Art von Frage möchtest du hinzufügen?"

      # Switching back restores «Ansehen».
      back_html = live |> element(~s|button[phx-value-mode="view"]|) |> render_click()
      assert back_html =~ q1.prompt
      refute back_html =~ "Welche Art von Frage möchtest du hinzufügen?"
    end

    test "clicking a card's edit button opens that question's form in edit mode", %{
      conn: conn,
      game: game,
      q2: q2
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")

      live |> element(~s|button[phx-value-mode="view"]|) |> render_click()

      live
      |> element(~s|button[phx-click="edit_question"][phx-value-id="#{q2.id}"]|)
      |> render_click()

      assert_patched(live, ~p"/games/#{game}/questions/#{q2}/edit")
      html = render(live)
      # Back in edit mode: the form for q2 is shown, not the participant stack.
      assert html =~ "Fragetext"
      assert html =~ q2.prompt
    end

    test "the question list jumps to a question on the page", %{
      conn: conn,
      game: game,
      q1: q1,
      q2: q2
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-mode="view"]|) |> render_click()

      for q <- [q1, q2] do
        assert has_element?(live, "#questions-#{q.id} a[href='#view-question-#{q.id}']")
        assert has_element?(live, "#view-question-#{q.id}")
      end
    end

    test "offers to add a question before, between and after the questions", %{
      conn: conn,
      scope: scope,
      game: game,
      q1: q1,
      q2: q2
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-mode="view"]|) |> render_click()

      for at <- 0..2, do: assert(has_element?(live, "#insert-question-#{at}", "Frage hinzufügen"))

      live |> element("#insert-question-1") |> render_click()
      assert_patched(live, ~p"/games/#{game}/questions?at=1")
      assert render(live) =~ "Neue Frage an Position 2"

      live
      |> element(~s|button[phx-click="create"][phx-value-type="text_input"]|)
      |> render_click()

      assert [first, new, last] = Quiz.Games.list_questions_for_game(scope, game)
      assert {first.id, last.id} == {q1.id, q2.id}
      assert new.type == :text_input
      assert Enum.map([first, new, last], & &1.position) == [1, 2, 3]
      assert_patched(live, ~p"/games/#{game}/questions/#{new}/edit")
    end
  end

  describe "Creating a question" do
    setup [:create_game]

    test "clicking a type card creates the question and opens its edit form", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")

      live |> element(~s|button[phx-value-type="single_choice"]|) |> render_click()

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.type == :single_choice
      assert_patched(live, ~p"/games/#{game}/questions/#{question}/edit")

      html = render(live)
      assert html =~ "Bearbeiten"
      assert html =~ ~s|value="single_choice"|
      assert html =~ "Antwortoptionen"
    end

    test "creating a multiple-choice question autosaves several correct options", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")

      live |> element(~s|button[phx-value-type="multiple_choice"]|) |> render_click()

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.type == :multiple_choice

      html = render(live)
      assert html =~ ~s|value="multiple_choice"|
      assert html =~ "Wähle alle richtigen aus"
      # The single-select hook must not be wired up here, or the second tick
      # would be undone in the browser before autosave sees it.
      refute html =~ "SingleCorrect"

      render_change(live, "validate", %{
        "question" => %{
          "type" => "multiple_choice",
          "prompt" => "Which of these are prime?",
          "position" => "42",
          "data" => %{
            "choices_sort" => ["0", "1", "2"],
            "choices" => %{
              "0" => %{"text" => "2", "correct" => "true"},
              "1" => %{"text" => "3", "correct" => "true"},
              "2" => %{"text" => "4", "correct" => "false"}
            }
          }
        }
      })

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.prompt == "Which of these are prime?"
      assert Enum.map(saved.data.choices, & &1.correct) == [true, true, false]
      assert render(live) =~ "3 Optionen · 2 richtig"
    end

    test "a freshly created question starts blank and shows a placeholder label", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")

      live |> element(~s|button[phx-value-type="text_input"]|) |> render_click()

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.prompt in [nil, ""]
      # The sidebar labels the still-unnamed question.
      assert render(live) =~ "Neue Frage"
    end

    test "appends new questions after the existing ones", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      existing = question_fixture(scope, %{game_id: game.id, position: 7})

      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-mode="edit"]|) |> render_click()
      live |> element(~s|button[phx-value-type="single_choice"]|) |> render_click()

      created =
        Quiz.Games.list_questions_for_game(scope, game)
        |> Enum.reject(&(&1.id == existing.id))
        |> hd()

      assert created.position == 8
    end

    test "editing autosaves the new question's content", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="text_input"]|) |> render_click()

      [question] = Quiz.Games.list_questions_for_game(scope, game)

      render_change(live, "validate", @text_input_submit_params)

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.prompt == "some updated prompt"
      assert Enum.map(saved.data.solutions, & &1.text) == ["Paris"]
    end

    test "a new sequence question shows its editor hint", %{conn: conn, game: game} do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="sequence"]|) |> render_click()

      html = render(live)
      assert html =~ "Die Reihenfolge ist die Lösung"
    end

    test "a new pin_on_image question shows the upload drop zone", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="pin_on_image"]|) |> render_click()

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.type == :pin_on_image

      html = render(live)
      assert html =~ ~s|value="pin_on_image"|
      assert html =~ "Hintergrundbild"
      assert html =~ "Bild hochladen"
      assert html =~ ~s|name="question[data][pin][image_key]"|
    end

    test "uploading a background image autosaves the pin_on_image question", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="pin_on_image"]|) |> render_click()

      image =
        file_input(live, "#question-form", :pin_image, [
          %{
            last_modified: 1_700_000_000_000,
            name: "paris.png",
            content: File.read!("test/support/fixtures/files/pin.png"),
            type: "image/png"
          }
        ])

      render_upload(image, "paris.png")
      render_change(live, "validate", @pin_submit_params)

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.type == :pin_on_image
      assert question.data.pin.target_x == 0.5

      image_key = question.data.pin.image_key
      assert String.starts_with?(image_key, "uploads/#{scope.user.id}/")
      assert String.ends_with?(image_key, ".png")

      dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
      stored_path = Path.join(dir, Path.relative_to(image_key, "uploads"))
      assert File.exists?(stored_path)

      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)
    end

    test "a validate while the upload is still in progress does not crash", %{
      conn: conn,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="pin_on_image"]|) |> render_click()

      image =
        file_input(live, "#question-form", :pin_image, [
          %{
            last_modified: 1_700_000_000_000,
            name: "paris.png",
            content: File.read!("test/support/fixtures/files/pin.png"),
            type: "image/png"
          }
        ])

      # Upload only part of the file: the entry is still in progress. A
      # validate (autosave) firing now must not raise — it previously crashed
      # the LiveView with "cannot consume uploaded files when entries are
      # still in progress".
      render_upload(image, "paris.png", 30)
      assert render_change(live, "validate", @pin_submit_params)
      assert Process.alive?(live.pid)
    end

    test "the uploaded image persists when the prompt was typed before the upload",
         %{conn: conn, scope: scope, game: game} do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="pin_on_image"]|) |> render_click()

      # Prompt typed first; the question is not yet valid (no image), so this
      # autosave does not persist — it only stashes the form params.
      render_change(live, "validate", @pin_submit_params)

      image =
        file_input(live, "#question-form", :pin_image, [
          %{
            last_modified: 1_700_000_000_000,
            name: "paris.png",
            content: File.read!("test/support/fixtures/files/pin.png"),
            type: "image/png"
          }
        ])

      # Completing the upload alone must persist the image — no extra validate
      # round-trip needed, because the progress callback re-uses the stashed
      # params and the prompt is already present.
      render_upload(image, "paris.png")

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.data.pin.image_key
      assert String.starts_with?(question.data.pin.image_key, "uploads/#{scope.user.id}/")

      dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
      stored_path = Path.join(dir, Path.relative_to(question.data.pin.image_key, "uploads"))
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)
    end

    test "the target coordinates a participant-author sets are persisted", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="pin_on_image"]|) |> render_click()

      image =
        file_input(live, "#question-form", :pin_image, [
          %{
            last_modified: 1_700_000_000_000,
            name: "paris.png",
            content: File.read!("test/support/fixtures/files/pin.png"),
            type: "image/png"
          }
        ])

      render_upload(image, "paris.png")

      # Uploading persists the pin immediately (with default centre coordinates);
      # the re-rendered form then carries the stored image_key in its hidden
      # input. Mirror that here so the coordinate change reflects the real DOM.
      [uploaded] = Quiz.Games.list_questions_for_game(scope, game)
      image_key = uploaded.data.pin.image_key

      # The hook writes the clicked target into the hidden inputs; simulate the
      # change it dispatches with a non-default target.
      params =
        @pin_submit_params
        |> put_in(["question", "data", "pin", "image_key"], image_key)
        |> put_in(["question", "data", "pin", "target_x"], "0.25")
        |> put_in(["question", "data", "pin", "target_y"], "0.75")

      render_change(live, "validate", params)

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      assert question.data.pin.target_x == 0.25
      assert question.data.pin.target_y == 0.75
      assert question.data.pin.image_key

      dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
      stored_path = Path.join(dir, Path.relative_to(question.data.pin.image_key, "uploads"))
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)
    end

    test "pin coordinate inputs render inside phx-update=ignore containers so " <>
           "autosave re-renders never stomp client-set values",
         %{conn: conn, scope: scope, game: game} do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions")
      live |> element(~s|button[phx-value-type="pin_on_image"]|) |> render_click()

      [question] = Quiz.Games.list_questions_for_game(scope, game)
      html = render(live)

      # The coordinate controls and the image box must be keyed by question id
      # and ignored, so a DOM patch from a concurrent autosave cannot reset a
      # just-placed target, and the image element is owned by the client hook.
      assert html =~ ~s|id="pin-controls-#{question.id}" phx-update="ignore"|
      assert html =~ ~s|id="pin-editor-box-#{question.id}" phx-update="ignore"|
      # The coordinate inputs themselves are present for the form submit.
      assert html =~ ~s|name="question[data][pin][target_x]"|
      assert html =~ ~s|name="question[data][pin][target_y]"|
    end
  end

  describe "Editing a question" do
    setup [:create_game_and_question]

    test "renders the form pre-filled", %{conn: conn, game: game, question: question} do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert html =~ "Bearbeiten"
      assert html =~ question.prompt
    end

    test "saves changes and, while a draft, accepts an incomplete edit leniently", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      # Draft quiz: a blank prompt does not raise a blocking validation error, so
      # the author can keep working on a half-finished question.
      refute live
             |> form("#question-form", question: @invalid_attrs)
             |> render_change() =~ "darf nicht leer sein"

      params =
        put_in(@single_choice_submit_params, ["question", "prompt"], "renamed prompt")

      render_submit(live, "save", params)

      html = render(live)
      assert html =~ "Frage erfolgreich aktualisiert"
      assert html =~ "renamed prompt"
    end

    test "saves a sanitized description and renders it in view mode", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      params =
        put_in(
          @single_choice_submit_params,
          ["question", "description"],
          "<strong>Hinweis</strong><script>alert(1)</script>"
        )

      render_submit(live, "save", params)
      assert render(live) =~ "Frage erfolgreich aktualisiert"

      # The stored HTML keeps allowed formatting and drops the script.
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.description == "<strong>Hinweis</strong>alert(1)"

      # The participant ("Ansehen") view renders the formatted description.
      view_html = live |> element(~s|button[phx-value-mode="view"]|) |> render_click()
      assert view_html =~ "<strong>Hinweis</strong>"
    end

    test "auto-saves edits on change with no manual save button", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      # Edit mode has no manual save control — neither header button nor footer bar.
      refute html =~ "Frage speichern"

      html =
        live
        |> form("#question-form", question: %{"prompt" => "autosaved prompt"})
        |> render_change()

      # A successful auto-save surfaces nothing in the header.
      refute html =~ "Nicht gespeichert"
      refute html =~ "Speichern fehlgeschlagen"

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.prompt == "autosaved prompt"
    end

    test "autosaves an incomplete change without an error while the quiz is a draft", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      html =
        live
        |> form("#question-form", question: %{"prompt" => ""})
        |> render_change()

      refute html =~ "Nicht gespeichert"
    end

    test "shows a save-error status in the header when a live question is made invalid", %{
      conn: conn,
      scope: scope
    } do
      # A non-draft (live) quiz holds its questions to the full validation rules,
      # so blanking a required field surfaces the save-error status.
      game = game_fixture(scope, %{status: :open})
      question = question_fixture(scope, %{game_id: game.id})

      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      html =
        live
        |> form("#question-form", question: %{"prompt" => ""})
        |> render_change()

      assert html =~ "Nicht gespeichert"
    end

    test "deletes the current question and returns to the type picker", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      # The menu item only opens the confirmation dialog; nothing is deleted yet.
      assert has_element?(live, "#delete-question[onclick*='delete_question_modal']")
      refute has_element?(live, "[data-confirm]")
      assert has_element?(live, "#delete_question_modal", question.prompt)

      live |> element("#delete_question_modal-confirm") |> render_click()

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

  describe "Question media (Bild oder Video)" do
    setup [:create_game_and_question]

    defp media_upload(live) do
      file_input(live, "#question-form", :media_image, [
        %{
          last_modified: 1_700_000_000_000,
          name: "media.png",
          content: File.read!("test/support/fixtures/files/pin.png"),
          type: "image/png"
        }
      ])
    end

    defp video_upload(live) do
      file_input(live, "#question-form", :media_video, [
        %{
          last_modified: 1_700_000_000_000,
          name: "clip.mp4",
          content: <<0, 0, 0, 24, "ftypmp42fake video payload">>,
          type: "video/mp4"
        }
      ])
    end

    defp local_storage_path(key) do
      dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
      Path.join(dir, Path.relative_to(key, "uploads"))
    end

    test "the form shows the media section with Bild/Video tabs", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert html =~ "Bild oder Video"
      assert html =~ "media-tab-image"
      assert html =~ "media-tab-video"
      assert html =~ ~s|name="question[media_image_key]"|
    end

    test "uploading an image autosaves the media_image_key", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      render_upload(media_upload(live), "media.png")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert String.starts_with?(saved.media_image_key, "uploads/#{scope.user.id}/")
      assert String.ends_with?(saved.media_image_key, ".png")

      dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
      stored_path = Path.join(dir, Path.relative_to(saved.media_image_key, "uploads"))
      assert File.exists?(stored_path)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      # The re-rendered form shows the preview and the remove button.
      html = render(live)
      assert html =~ "remove-media-image"
      assert html =~ "Bild ersetzen"
    end

    test "uploading a video autosaves the media_video_key and shows the preview", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      live |> element("#media-tab-video") |> render_click()
      render_upload(video_upload(live), "clip.mp4")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert String.starts_with?(saved.media_video_key, "uploads/#{scope.user.id}/")
      assert String.ends_with?(saved.media_video_key, ".mp4")

      stored_path = local_storage_path(saved.media_video_key)
      assert File.exists?(stored_path)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      html = render(live)
      assert html =~ "remove-media-video"
      assert html =~ "Video ersetzen"
    end

    test "uploading a video clears a previously uploaded image", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      render_upload(media_upload(live), "media.png")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.media_image_key

      stored_path = local_storage_path(saved.media_image_key)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      live |> element("#media-tab-video") |> render_click()
      render_upload(video_upload(live), "clip.mp4")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.media_video_key
      assert saved.media_image_key == nil
    end

    test "uploading an image clears a previously uploaded video", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      live |> element("#media-tab-video") |> render_click()
      render_upload(video_upload(live), "clip.mp4")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.media_video_key

      stored_path = local_storage_path(saved.media_video_key)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      live |> element("#media-tab-image") |> render_click()
      render_upload(media_upload(live), "media.png")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.media_image_key
      assert saved.media_video_key == nil
    end

    test "the remove buttons clear the stored media", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      render_upload(media_upload(live), "media.png")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.media_image_key

      stored_path = local_storage_path(saved.media_image_key)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      live |> element("#remove-media-image") |> render_click()
      assert Quiz.Games.get_question!(scope, question.id).media_image_key == nil

      live |> element("#media-tab-video") |> render_click()
      render_upload(video_upload(live), "clip.mp4")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.media_video_key

      video_path = local_storage_path(saved.media_video_key)
      on_exit(fn -> File.rm_rf(Path.dirname(video_path)) end)

      live |> element("#remove-media-video") |> render_click()
      assert Quiz.Games.get_question!(scope, question.id).media_video_key == nil
    end
  end

  describe "Lösungserklärung (Bild oder Video)" do
    setup [:create_game_and_question]

    defp solution_image_upload(live) do
      file_input(live, "#question-form", :solution_image, [
        %{
          last_modified: 1_700_000_000_000,
          name: "erklaerung.png",
          content: File.read!("test/support/fixtures/files/pin.png"),
          type: "image/png"
        }
      ])
    end

    defp solution_video_upload(live) do
      file_input(live, "#question-form", :solution_video, [
        %{
          last_modified: 1_700_000_000_000,
          name: "erklaerung.mp4",
          content: <<0, 0, 0, 24, "ftypmp42fake video payload">>,
          type: "video/mp4"
        }
      ])
    end

    test "the form shows the explanation section with Bild/Video tabs", %{
      conn: conn,
      game: game,
      question: question
    } do
      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert html =~ "Lösungserklärung"
      assert html =~ "solution-tab-image"
      assert html =~ "solution-tab-video"
      assert html =~ ~s|name="question[solution_image_key]"|
    end

    test "uploading an image autosaves the solution_image_key", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      render_upload(solution_image_upload(live), "erklaerung.png")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert String.starts_with?(saved.solution_image_key, "uploads/#{scope.user.id}/")
      assert String.ends_with?(saved.solution_image_key, ".png")

      stored_path = local_storage_path(saved.solution_image_key)
      assert File.exists?(stored_path)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      html = render(live)
      assert html =~ "remove-solution-image"
      assert html =~ "Bild ersetzen"
    end

    test "uploading a video autosaves the solution_video_key and shows the preview", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      live |> element("#solution-tab-video") |> render_click()
      render_upload(solution_video_upload(live), "erklaerung.mp4")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert String.starts_with?(saved.solution_video_key, "uploads/#{scope.user.id}/")
      assert String.ends_with?(saved.solution_video_key, ".mp4")

      stored_path = local_storage_path(saved.solution_video_key)
      assert File.exists?(stored_path)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      html = render(live)
      assert html =~ "remove-solution-video"
      assert html =~ "Video ersetzen"
      assert html =~ Quiz.Storage.url(saved.solution_video_key)
    end

    test "reopening the form lands on the Video tab when a video is stored", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, question} =
        Quiz.Games.update_question(scope, question, %{
          solution_video_key: "uploads/#{scope.user.id}/stored.mp4"
        })

      {:ok, _live, html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert html =~ ~s|name="question[solution_video_key]"|
      assert html =~ "remove-solution-video"
      refute html =~ ~s|name="question[solution_image_key]"|
    end

    test "uploading a video clears a previously uploaded image", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      render_upload(solution_image_upload(live), "erklaerung.png")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.solution_image_key

      stored_path = local_storage_path(saved.solution_image_key)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      live |> element("#solution-tab-video") |> render_click()
      render_upload(solution_video_upload(live), "erklaerung.mp4")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.solution_video_key
      assert saved.solution_image_key == nil
    end

    test "uploading an image clears a previously uploaded video", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      live |> element("#solution-tab-video") |> render_click()
      render_upload(solution_video_upload(live), "erklaerung.mp4")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.solution_video_key

      stored_path = local_storage_path(saved.solution_video_key)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      live |> element("#solution-tab-image") |> render_click()
      render_upload(solution_image_upload(live), "erklaerung.png")

      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.solution_image_key
      assert saved.solution_video_key == nil
    end

    test "the explanation upload leaves the question's own media alone", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, question} =
        Quiz.Games.update_question(scope, question, %{
          media_image_key: "uploads/#{scope.user.id}/frage.png"
        })

      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      live |> element("#solution-tab-video") |> render_click()
      render_upload(solution_video_upload(live), "erklaerung.mp4")

      saved = Quiz.Games.get_question!(scope, question.id)
      on_exit(fn -> File.rm_rf(Path.dirname(local_storage_path(saved.solution_video_key))) end)

      assert saved.solution_video_key
      assert saved.media_image_key == "uploads/#{scope.user.id}/frage.png"
    end

    test "the remove buttons clear the stored explanation media", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      render_upload(solution_image_upload(live), "erklaerung.png")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.solution_image_key

      stored_path = local_storage_path(saved.solution_image_key)
      on_exit(fn -> File.rm_rf(Path.dirname(stored_path)) end)

      live |> element("#remove-solution-image") |> render_click()
      assert Quiz.Games.get_question!(scope, question.id).solution_image_key == nil

      live |> element("#solution-tab-video") |> render_click()
      render_upload(solution_video_upload(live), "erklaerung.mp4")
      saved = Quiz.Games.get_question!(scope, question.id)
      assert saved.solution_video_key

      video_path = local_storage_path(saved.solution_video_key)
      on_exit(fn -> File.rm_rf(Path.dirname(video_path)) end)

      live |> element("#remove-solution-video") |> render_click()
      assert Quiz.Games.get_question!(scope, question.id).solution_video_key == nil
    end
  end

  describe "Hints from the text import" do
    setup %{scope: scope} do
      {:ok, parsed} =
        Quiz.Games.TextFormat.parse("""
        Quiz: Hinweise
        Frage: Welcher Pilz ist das?
        Typ: Texteingabe
        Bild: Foto eines Fliegenpilzes
        Lösung: Fliegenpilz

        Frage: Wo liegt der Nationalpark?
        Typ: Pin auf Bild
        Bild: Karte der Schweiz
        Pin: im Unterengadin
        """)

      {:ok, game} = Quiz.Games.import_game(scope, parsed)
      [question, pin] = Quiz.Games.list_questions_for_game(scope, game)
      %{game: game, question: question, pin: pin}
    end

    test "names the image a question needs until one is uploaded", %{
      conn: conn,
      scope: scope,
      game: game,
      question: question
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{question}/edit")

      assert has_element?(live, "#image-hint", "Foto eines Fliegenpilzes")
      assert has_element?(live, "#image-hint a[href^='https://commons.wikimedia.org/']")

      render_upload(media_upload(live), "media.png")
      on_exit(fn -> Quiz.Storage.delete_prefix(Quiz.Storage.user_prefix(scope.user.id)) end)

      refute has_element?(live, "#image-hint")
    end

    test "names the background image and where the pin belongs", %{
      conn: conn,
      game: game,
      pin: pin
    } do
      {:ok, live, _html} = live(conn, ~p"/games/#{game}/questions/#{pin}/edit")

      assert has_element?(live, "#pin-image-hint", "Karte der Schweiz")
      assert has_element?(live, "#pin-hint", "im Unterengadin")
    end
  end
end
