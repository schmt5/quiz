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

      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(lv, "#finished-stage")
      assert has_element?(lv, "#finished-review-hint")
      assert html =~ "Lösungen besprechen"
      # The walkthrough starts at the first question's position.
      assert html =~ ~p"/games/#{game}/review/1"
    end

    test "without questions, the ranking is the call-to-action", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :closed})

      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(lv, "#finished-stage")
      refute has_element?(lv, "#finished-review-hint")
      refute html =~ "Lösungen besprechen"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end

    test "per_question mode skips the end-of-game walkthrough link", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      game = set_game_status(game, :finished)

      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(lv, "#finished-stage")
      # No walkthrough in this mode, so the guests aren't promised one.
      refute has_element?(lv, "#finished-review-hint")
      refute html =~ "Lösungen besprechen"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end

    test "survives the grading being published while the host screen stays open",
         %{conn: conn, scope: scope} do
      game = game_fixture(scope)
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      game = set_game_status(game, :finished)

      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      # The operator publishes the grading from the correction view — broadcast
      # on the same "game:<id>" topic the host subscribed to in mount. The host
      # must not crash on a message type it doesn't act on.
      {:ok, _game} = Play.publish_grading(scope, game)

      assert has_element?(lv, "#finished-stage")
    end
  end

  describe "removing a team from the roster" do
    test "the roster shrinks after the remove button is clicked", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})
      {:ok, participant, _token} = Play.enroll(game, "Schlechter Name")

      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")
      assert html =~ "Schlechter Name"

      assert has_element?(lv, "#remove_participant_modal_#{participant.id}", "Schlechter Name")

      lv
      |> element("#remove_participant_modal_#{participant.id}-confirm")
      |> render_click()

      refute render(lv) =~ "Schlechter Name"
      assert Play.list_participants(game) == []
    end
  end

  describe "starting from the lobby" do
    setup %{scope: scope} do
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      %{game: game}
    end

    test "without teams, «Quiz starten» asks first", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      refute has_element?(lv, "#start-run[disabled]")
      refute has_element?(lv, "#start-run[phx-click]")
      assert has_element?(lv, "#start-run[onclick*='start_without_teams_modal']")
      assert has_element?(lv, "#start_without_teams_modal-confirm", "Ja, trotzdem starten")

      lv |> element("#start_without_teams_modal-confirm") |> render_click()
      assert Quiz.Repo.reload(game).status == :running
    end

    test "with teams, «Quiz starten» starts right away", %{conn: conn, game: game} do
      {:ok, _participant, _token} = Play.enroll(game, "Team A")
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      refute has_element?(lv, "#start-run[onclick]")
      lv |> element("#start-run") |> render_click()
      assert Quiz.Repo.reload(game).status == :running
    end

    test "the settings menu holds the other lobby actions", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open, intro_text: "Handys weg."})
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(lv, "#lobby-settings #lobby-toggle-enrollment", "Anmeldung sperren")
      assert has_element?(lv, "#lobby-settings #lobby-intro", "Info und Spielregeln")
      assert has_element?(lv, "#lobby-settings #open-screen[target='_blank']")

      assert has_element?(
               lv,
               "#lobby-settings #lobby-edit-quiz[href='/games/#{game.id}/questions']"
             )

      assert has_element?(lv, "#lobby-settings li", "Keine neuen Teams mehr zulassen")
    end
  end

  describe "locking enrollment from the lobby" do
    test "the toggle closes and re-opens the doors, flipping label and DB flag",
         %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})

      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")
      assert html =~ "Anmeldung sperren"
      refute html =~ "Anmeldung gesperrt"

      # Lock it.
      html = lv |> element("button[phx-click=toggle_enrollment]") |> render_click()
      assert html =~ "Anmeldung gesperrt"
      assert html =~ "Anmeldung öffnen"
      assert Quiz.Repo.reload(game).enrollment_locked

      # And back open.
      html = lv |> element("button[phx-click=toggle_enrollment]") |> render_click()
      assert html =~ "Anmeldung sperren"
      refute html =~ "Anmeldung gesperrt"
      refute Quiz.Repo.reload(game).enrollment_locked
    end

    test "the toggle is available during a running quiz too", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      {:ok, running} = Play.start_run(scope, game)

      {:ok, lv, _html} = live(conn, ~p"/games/#{running}/run")

      lv |> element("button[phx-click=toggle_enrollment]") |> render_click()
      assert Quiz.Repo.reload(running).enrollment_locked
    end
  end

  describe "intro & outro modals" do
    test "the lobby offers the intro modal when intro content exists",
         %{conn: conn, scope: scope} do
      game =
        game_fixture(scope, %{
          status: :open,
          intro_text: "Handys weg, pro Team eine Antwort.",
          intro_image_key: "uploads/1/logo.png"
        })

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Infos &amp; Spielregeln"
      assert html =~ "Handys weg, pro Team eine Antwort."
      assert html =~ Quiz.Storage.url("uploads/1/logo.png")
      assert html =~ ~s|id="intro_modal"|
    end

    test "the lobby shows no intro button without intro content", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      refute html =~ "intro_modal"
      refute html =~ "Infos &amp; Spielregeln"
    end

    test "the finished screen offers the outro modal when outro content exists",
         %{conn: conn, scope: scope} do
      game =
        game_fixture(scope, %{
          outro_text: "Danke und bis zum nächsten Mal!",
          outro_image_key: "uploads/1/sponsor.png"
        })

      question_fixture(scope, %{game_id: game.id, position: 1})
      game = set_game_status(game, :finished)

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Abschluss &amp; Infos"
      assert html =~ "Danke und bis zum nächsten Mal!"
      assert html =~ Quiz.Storage.url("uploads/1/sponsor.png")
      assert html =~ ~s|id="outro_modal"|
    end

    test "a running quiz shows neither modal", %{conn: conn, scope: scope} do
      game =
        game_fixture(scope, %{
          status: :open,
          intro_text: "Spielregeln",
          outro_text: "Danke!"
        })

      question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, running} = Play.start_run(scope, game)

      {:ok, _lv, html} = live(conn, ~p"/games/#{running}/run")

      refute html =~ "intro_modal"
      refute html =~ "outro_modal"
    end

    test "the finished screen shows no outro button without outro content",
         %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :closed})

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      refute html =~ "outro_modal"
      refute html =~ "Abschluss &amp; Infos"
    end
  end

  describe "lobby roster" do
    test "a team is not listed twice if it arrives in the initial list and a broadcast",
         %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})

      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      # Enrolling broadcasts {:participant_joined, _}; the host appends it once.
      {:ok, participant, _token} = Play.enroll(game, "Team A")

      # Simulate the subscribe/list-load race delivering the same join again.
      send(lv.pid, {:participant_joined, participant})

      html = render(lv)
      occurrences = (html |> String.split(~s|id="participant-#{participant.id}"|) |> length()) - 1
      assert occurrences == 1
    end
  end

  describe "question media" do
    test "renders the question image below the prompt", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        media_image_key: "uploads/1/media.png"
      })

      {:ok, running} = Play.start_run(scope, game)
      {:ok, _lv, html} = live(conn, ~p"/games/#{running}/run")

      assert html =~ Quiz.Storage.url("uploads/1/media.png")
    end

    test "the question image enlarges into a lightbox", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})

      question =
        question_fixture(scope, %{
          game_id: game.id,
          position: 1,
          media_image_key: "uploads/1/media.png"
        })

      {:ok, running} = Play.start_run(scope, game)
      {:ok, lv, _html} = live(conn, ~p"/games/#{running}/run")

      assert has_element?(lv, ~s|button[aria-label="Bild vergrössern"]|)
      assert has_element?(lv, "dialog#zoom-media-#{question.id}")
    end

    test "renders the uploaded video without autoplay", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        media_video_key: "uploads/1/clip.mp4"
      })

      {:ok, running} = Play.start_run(scope, game)
      {:ok, _lv, html} = live(conn, ~p"/games/#{running}/run")

      assert html =~ ~s|<video src="#{Quiz.Storage.url("uploads/1/clip.mp4")}"|
      assert html =~ ~s|preload="none"|
      refute html =~ "autoplay"
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
      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(lv, "#reveal[title^='Auswerten']", "Weiter")
      assert has_element?(lv, "#retreat", "Zurück")
      assert html =~ "Teams haben geantwortet"
      refute html =~ "Akzeptierte Antwort"
    end

    test "clicking Auswerten reveals the solution and the advance button",
         %{conn: conn, scope: scope, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      html = lv |> element("#reveal") |> render_click()

      # The persisted reveal flips the run into the revealing sub-phase.
      assert Quiz.Games.get_game!(scope, game.id).revealing

      # Solution is now shown; the live answer count gives way to the advance step
      # ("Quiz beenden" here, since this is the only/last question).
      assert html =~ "Akzeptierte Antwort"
      assert html =~ "Paris"
      assert has_element?(lv, "#advance[title^='Quiz beenden']", "Weiter")
      refute has_element?(lv, "#reveal")
      refute html =~ "Teams haben geantwortet"
      # Stats stay behind the toggle, as on the end-review screen.
      assert html =~ "Statistik einblenden"
    end
  end

  describe "revealing a multiple_choice question" do
    setup %{scope: scope} do
      game =
        game_fixture(scope, %{status: :open, review_mode: :per_question, show_statistics: true})

      question =
        question_fixture(scope, %{
          game_id: game.id,
          position: 1,
          type: :multiple_choice,
          prompt: "Welche dieser Städte liegen in Europa?",
          data: %{
            choices: [
              %{text: "Lissabon", correct: true},
              %{text: "Oslo", correct: true},
              %{text: "Kairo", correct: false}
            ]
          }
        })

      {:ok, running} = Play.start_run(scope, game)
      {:ok, participant, _token} = Play.enroll(running, "Team A")

      {:ok, _answer} =
        Play.submit_answer(running, participant, question, %{"answer" => ["0", "1"]})

      %{game: running, question: question}
    end

    test "the solution marks every correct option and the stats note multiple picks",
         %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      html = lv |> element("#reveal") |> render_click()

      assert html =~ "Lissabon"
      assert html =~ "Oslo"
      assert html =~ "Kairo"

      html = lv |> element("button", "Statistik einblenden") |> render_click()

      assert html =~ "Mehrfachnennungen möglich"
    end
  end

  describe "solution explanation (revealing)" do
    setup %{scope: scope} do
      game =
        game_fixture(scope, %{status: :open, review_mode: :per_question})

      %{game: game}
    end

    defp reveal_with_explanation(conn, scope, game, explanation_attrs) do
      question_fixture(
        scope,
        Map.merge(
          %{
            game_id: game.id,
            position: 1,
            type: :text_input,
            prompt: "Hauptstadt von Frankreich?"
          },
          explanation_attrs
        )
      )

      {:ok, running} = Play.start_run(scope, game)
      {:ok, lv, _html} = live(conn, ~p"/games/#{running}/run")

      lv |> element("#reveal") |> render_click()
    end

    test "an explanation image and text are shown on reveal", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      html =
        reveal_with_explanation(conn, scope, game, %{
          solution_text: "Seit 987 die Hauptstadt.",
          solution_image_key: "uploads/1/erklaerung.png"
        })

      assert html =~ "Erklärung"
      assert html =~ "Seit 987 die Hauptstadt."
      assert html =~ Quiz.Storage.url("uploads/1/erklaerung.png")
    end

    test "the explanation image enlarges into a lightbox", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      question =
        question_fixture(scope, %{
          game_id: game.id,
          position: 1,
          type: :text_input,
          solution_image_key: "uploads/1/erklaerung.png"
        })

      {:ok, running} = Play.start_run(scope, game)
      {:ok, lv, _html} = live(conn, ~p"/games/#{running}/run")
      lv |> element("#reveal") |> render_click()

      assert has_element?(lv, "dialog#zoom-solution-#{question.id}")
    end

    test "the pin solution image enlarges into a lightbox", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      question =
        question_fixture(scope, %{game_id: game.id, position: 1, type: :pin_on_image})

      {:ok, running} = Play.start_run(scope, game)
      {:ok, lv, _html} = live(conn, ~p"/games/#{running}/run")
      lv |> element("#reveal") |> render_click()

      assert has_element?(lv, "dialog#zoom-pin-#{question.id}")
    end

    test "an explanation video is shown on reveal, without autoplay", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      html =
        reveal_with_explanation(conn, scope, game, %{
          solution_video_key: "uploads/1/erklaerung.mp4"
        })

      assert html =~ "Erklärung"
      assert html =~ ~s|src="#{Quiz.Storage.url("uploads/1/erklaerung.mp4")}"|
      assert html =~ ~s|preload="none"|
      refute html =~ "autoplay"
    end

    test "nothing is rendered when the question has no explanation", %{
      conn: conn,
      scope: scope,
      game: game
    } do
      html = reveal_with_explanation(conn, scope, game, %{})

      refute html =~ "Erklärung"
    end
  end

  describe "answer options in the sidebar (running)" do
    setup %{scope: scope} do
      game =
        game_fixture(scope, %{status: :open, review_mode: :per_question, show_statistics: false})

      question_fixture(scope, %{
        game_id: game.id,
        position: 1,
        type: :single_choice,
        prompt: "Höchster Berg der Schweiz?",
        data: %{
          choices: [
            %{text: "Eiger", correct: false},
            %{text: "Dufourspitze", correct: true},
            %{text: "Matterhorn", correct: false}
          ]
        }
      })

      question_fixture(scope, %{
        game_id: game.id,
        position: 2,
        type: :sequence,
        data: %{
          items: [%{text: "Eins"}, %{text: "Zwei"}, %{text: "Drei"}, %{text: "Vier"}]
        }
      })

      {:ok, _participant, _token} = Play.enroll(game, "Bergfreunde")
      {:ok, running} = Play.start_run(scope, game)
      %{game: running}
    end

    test "the Antworten tab is open by default and lists the lettered options, unmarked",
         %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      assert has_element?(lv, "#sidebar-tab-options[aria-selected=true]")
      assert has_element?(lv, "#options-preview li:nth-child(1)", "Eiger")
      assert has_element?(lv, "#options-preview li:nth-child(2)", "B")
      assert has_element?(lv, "#options-preview li:nth-child(2)", "Dufourspitze")
      assert has_element?(lv, "#options-preview li:nth-child(3)", "Matterhorn")
      # Projected while teams are still answering: nothing gives the answer away.
      refute has_element?(lv, "#options-preview .hero-check-circle-solid")
      refute has_element?(lv, "#participants-roster")
    end

    test "the Teams tab shows the roster, and the choice survives the next question",
         %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      lv |> element("#sidebar-tab-teams") |> render_click()

      assert has_element?(lv, "#sidebar-tab-teams[aria-selected=true]")
      assert has_element?(lv, "#participants-roster", "Bergfreunde")
      refute has_element?(lv, "#options-preview")

      lv |> element("#reveal") |> render_click()
      lv |> element("#advance") |> render_click()

      assert has_element?(lv, "#participants-roster", "Bergfreunde")

      lv |> element("#sidebar-tab-options") |> render_click()
      assert has_element?(lv, "#options-preview")
    end

    test "Auswerten marks the correct option in the preview", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      lv |> element("#reveal") |> render_click()

      assert has_element?(lv, "#options-preview li:nth-child(2) .hero-check-circle-solid")
      refute has_element?(lv, "#options-preview li:nth-child(1) .hero-check-circle-solid")
    end

    test "sequence items are not shown in their solution order", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      lv |> element("#reveal") |> render_click()
      lv |> element("#advance") |> render_click()

      shown =
        lv
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("#options-preview li")
        |> Enum.map(&String.trim(LazyHTML.text(&1)))

      assert Enum.sort(shown) == Enum.sort(["Eins", "Zwei", "Drei", "Vier"])
      refute shown == ["Eins", "Zwei", "Drei", "Vier"]
    end
  end

  describe "sidebar outside a running question" do
    test "the lobby and the finished screen show no tabs", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})

      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")
      refute has_element?(lv, "#sidebar-tab-options")

      {:ok, lv, _html} = live(conn, ~p"/games/#{set_game_status(game, :finished)}/run")
      refute has_element?(lv, "#sidebar-tab-options")
      assert has_element?(lv, "#participants-roster")
    end
  end

  describe "keyboard shortcuts" do
    defp shortcut(lv, action), do: render_hook(lv, "shortcut", %{"action" => action})

    defp running_game(scope, attrs) do
      game = game_fixture(scope, Map.merge(%{status: :open}, attrs))
      question_fixture(scope, %{game_id: game.id, position: 1, prompt: "Erste Frage"})
      question_fixture(scope, %{game_id: game.id, position: 2, prompt: "Zweite Frage"})
      {:ok, running} = Play.start_run(scope, game)
      running
    end

    test "next and prev step through the questions", %{conn: conn, scope: scope} do
      game = running_game(scope, %{})
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      # prev on the first question does nothing
      assert shortcut(lv, "prev") =~ "Erste Frage"

      assert shortcut(lv, "next") =~ "Zweite Frage"
      assert shortcut(lv, "prev") =~ "Erste Frage"
    end

    test "next never ends the quiz, it points at the button instead",
         %{conn: conn, scope: scope} do
      game = running_game(scope, %{})
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      shortcut(lv, "next")
      shortcut(lv, "next")

      assert has_element?(lv, "#finish-hint")
      assert Quiz.Games.get_game!(scope, game.id).status == :running
    end

    test "in per_question mode next reveals first, and S toggles the statistics",
         %{conn: conn, scope: scope} do
      game = running_game(scope, %{review_mode: :per_question, show_statistics: true})
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      shortcut(lv, "next")
      assert Quiz.Games.get_game!(scope, game.id).revealing

      shortcut(lv, "stats")
      assert Quiz.Games.get_game!(scope, game.id).screen_show_stats

      assert shortcut(lv, "next") =~ "Zweite Frage"
    end

    test "on the finished screen next opens the solution walkthrough",
         %{conn: conn, scope: scope} do
      game = game_fixture(scope)
      question_fixture(scope, %{game_id: game.id, position: 1})
      game = set_game_status(game, :finished)
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      shortcut(lv, "next")

      assert_redirect(lv, ~p"/games/#{game}/review/1")
    end
  end
end
