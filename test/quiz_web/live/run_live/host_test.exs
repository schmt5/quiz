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

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Quiz beendet."
      assert html =~ "Lösungen besprechen"
      # The walkthrough starts at the first question's position.
      assert html =~ ~p"/games/#{game}/review/1"
    end

    test "without questions, the ranking is the call-to-action", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :closed})

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Quiz beendet."
      refute html =~ "Lösungen besprechen"
      assert html =~ ~p"/games/#{game}/leaderboard"
    end

    test "per_question mode skips the end-of-game walkthrough link", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 1, type: :single_choice})
      game = set_game_status(game, :finished)

      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Quiz beendet."
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

      assert render(lv) =~ "Quiz beendet."
      assert Process.alive?(lv.pid)
    end
  end

  describe "removing a team from the roster" do
    test "the roster shrinks after the remove button is clicked", %{conn: conn, scope: scope} do
      game = game_fixture(scope, %{status: :open})
      {:ok, participant, _token} = Play.enroll(game, "Schlechter Name")

      {:ok, lv, html} = live(conn, ~p"/games/#{game}/run")
      assert html =~ "Schlechter Name"

      lv
      |> element("#participant-#{participant.id} button[phx-click=remove_participant]")
      |> render_click()

      refute render(lv) =~ "Schlechter Name"
      assert Play.list_participants(game) == []
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
      {:ok, _lv, html} = live(conn, ~p"/games/#{game}/run")

      assert html =~ "Auswerten"
      assert html =~ "Teams haben geantwortet"
      refute html =~ "Akzeptierte Antwort"
    end

    test "clicking Auswerten reveals the solution and the advance button",
         %{conn: conn, scope: scope, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/games/#{game}/run")

      html = lv |> element("button", "Auswerten") |> render_click()

      # The persisted reveal flips the run into the revealing sub-phase.
      assert Quiz.Games.get_game!(scope, game.id).revealing

      # Solution is now shown; the live answer count gives way to the advance step
      # ("Quiz beenden" here, since this is the only/last question).
      assert html =~ "Akzeptierte Antwort"
      assert html =~ "Paris"
      assert html =~ "Quiz beenden"
      refute html =~ "Auswerten"
      refute html =~ "Teams haben geantwortet"
      # Stats stay behind the toggle, as on the end-review screen.
      assert html =~ "Statistik einblenden"
    end
  end
end
