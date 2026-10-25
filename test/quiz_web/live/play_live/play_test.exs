defmodule QuizWeb.PlayLive.PlayTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  alias Quiz.Play
  alias QuizWeb.QuestionLive.AnswerArea

  # Drives the participant runtime the way the browser does: mount, restore the
  # team from its signed token (the JS hook does this via localStorage), then
  # submit the answer form.
  defp connect_and_restore(conn, game, token) do
    {:ok, lv, _html} = live(conn, ~p"/play/#{game.join_code}")
    render_hook(lv, "restore_participant", %{"token" => token})
    lv
  end

  describe "unknown run broadcasts" do
    setup do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, _participant, token} = Play.enroll(running, "Team A")

      %{game: running, token: token}
    end

    test "a message type this view doesn't handle never crashes it", %{
      conn: conn,
      game: game,
      token: token
    } do
      lv = connect_and_restore(conn, game, token)

      send(lv.pid, {:some_future_broadcast, :payload})

      assert render(lv) =~ "Team A"
    end
  end

  describe "removing a team" do
    test "the removed team's screen is sent back to the join page", %{conn: conn} do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, participant, token} = Play.enroll(running, "Team A")

      lv = connect_and_restore(conn, running, token)

      {:ok, _} = Play.remove_participant(scope, running, participant)

      assert_redirect(lv, ~p"/join?code=#{running.join_code}")
    end

    test "other teams' screens are unaffected", %{conn: conn} do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, kicked, _kicked_token} = Play.enroll(running, "Kicked")
      {:ok, _stays, token} = Play.enroll(running, "Stays")

      lv = connect_and_restore(conn, running, token)

      {:ok, _} = Play.remove_participant(scope, running, kicked)

      assert render(lv) =~ "Stays"
    end
  end

  describe "publishing the grading" do
    test "a connected participant renders the standings from the broadcast", %{conn: conn} do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question = question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, participant, token} = Play.enroll(running, "Team A")
      Play.submit_answer(running, participant, question, %{"answer" => "0"})

      lv = connect_and_restore(conn, running, token)

      {:ok, finished} = Play.advance_run(scope, running)
      {:ok, _published} = Play.publish_grading(scope, finished)

      html = render(lv)
      assert html =~ "Quiz zu Ende"
      assert html =~ "Rangliste"
      assert html =~ "Team A"
    end
  end

  describe "sequence answers are graded against the authoring order" do
    setup do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question = question_fixture(scope, %{game_id: game.id, position: 1, type: :sequence})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, participant, token} = Play.enroll(running, "Team A")

      %{game: running, question: question, participant: participant, token: token}
    end

    test "the correct order earns full credit even though items are shuffled for display",
         %{conn: conn, game: game, question: question, participant: participant, token: token} do
      lv = connect_and_restore(conn, game, token)

      correct_ids = Enum.map(question.data.items, & &1.id)

      lv
      |> form("form[phx-submit=answer_submit]")
      |> render_submit(%{"answer" => Enum.join(correct_ids, ",")})

      assert Play.get_answer(participant, question).grade == :full
    end

    test "a wrong order earns zero", %{
      conn: conn,
      game: game,
      question: question,
      participant: participant,
      token: token
    } do
      lv = connect_and_restore(conn, game, token)

      wrong_ids = question.data.items |> Enum.map(& &1.id) |> Enum.reverse()

      lv
      |> form("form[phx-submit=answer_submit]")
      |> render_submit(%{"answer" => Enum.join(wrong_ids, ",")})

      assert Play.get_answer(participant, question).grade == :zero
    end
  end

  describe "multiple choice answers" do
    setup do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      # choices: A correct, B correct, C incorrect
      question =
        question_fixture(scope, %{game_id: game.id, position: 1, type: :multiple_choice})

      {:ok, running} = Play.start_run(scope, game)
      {:ok, participant, token} = Play.enroll(running, "Team A")

      %{game: running, question: question, participant: participant, token: token}
    end

    test "the answer area offers checkboxes and says several answers are possible",
         %{conn: conn, game: game, token: token} do
      html = conn |> connect_and_restore(game, token) |> render()

      assert html =~ "Mehrere Antworten möglich"
      assert html =~ ~s|type="checkbox"|
      assert html =~ ~s|name="answer[]"|
    end

    test "ticking every correct option and nothing else earns full credit",
         %{conn: conn, game: game, question: question, participant: participant, token: token} do
      lv = connect_and_restore(conn, game, token)

      lv
      |> form("form[phx-submit=answer_submit]")
      |> render_submit(%{"answer" => ["0", "1"]})

      assert Play.get_answer(participant, question).grade == :full
    end

    test "ticking only part of the correct options earns half credit",
         %{conn: conn, game: game, question: question, participant: participant, token: token} do
      lv = connect_and_restore(conn, game, token)

      lv
      |> form("form[phx-submit=answer_submit]")
      |> render_submit(%{"answer" => ["0"]})

      assert Play.get_answer(participant, question).grade == :half
    end

    test "one correct plus one wrong tick earns nothing",
         %{conn: conn, game: game, question: question, participant: participant, token: token} do
      lv = connect_and_restore(conn, game, token)

      lv
      |> form("form[phx-submit=answer_submit]")
      |> render_submit(%{"answer" => ["0", "2"]})

      assert Play.get_answer(participant, question).grade == :zero
    end

    test "the submitted summary lists every picked option",
         %{conn: conn, game: game, token: token} do
      lv = connect_and_restore(conn, game, token)

      html =
        lv
        |> form("form[phx-submit=answer_submit]")
        |> render_submit(%{"answer" => ["0", "1"]})

      assert html =~ "A"
      assert html =~ "B"
    end
  end

  describe "question media" do
    defp start_running_game(media_attrs) do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, Map.merge(%{game_id: game.id, position: 1}, media_attrs))
      {:ok, running} = Play.start_run(scope, game)
      {:ok, _participant, token} = Play.enroll(running, "Team A")
      %{game: running, token: token}
    end

    test "renders the question image below the prompt", %{conn: conn} do
      %{game: game, token: token} = start_running_game(%{media_image_key: "uploads/1/media.png"})

      lv = connect_and_restore(conn, game, token)

      assert render(lv) =~ Quiz.Storage.url("uploads/1/media.png")
    end

    test "the participant view shows a plain image, not a lightbox", %{conn: conn} do
      %{game: game, token: token} = start_running_game(%{media_image_key: "uploads/1/media.png"})

      lv = connect_and_restore(conn, game, token)

      refute has_element?(lv, "dialog.modal")
    end

    test "a reveal image starts covered by tiles", %{conn: conn} do
      %{game: game, token: token} =
        start_running_game(%{media_image_key: "uploads/1/media.png", media_image_reveal: true})

      lv = connect_and_restore(conn, game, token)

      assert has_element?(lv, "[id^=reveal-media-] [data-tiles]")
    end

    test "renders the uploaded video for a video question", %{conn: conn} do
      %{game: game, token: token} =
        start_running_game(%{media_video_key: "uploads/1/clip.mp4"})

      lv = connect_and_restore(conn, game, token)

      html = render(lv)
      assert html =~ ~s|<video src="#{Quiz.Storage.url("uploads/1/clip.mp4")}"|
      assert html =~ ~s|preload="none"|
    end
  end

  describe "changing a submitted answer" do
    setup do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      q1 = question_fixture(scope, %{game_id: game.id, position: 1, type: :text_input})
      q2 = question_fixture(scope, %{game_id: game.id, position: 2})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, participant, token} = Play.enroll(running, "Team A")

      %{scope: scope, game: running, q1: q1, q2: q2, participant: participant, token: token}
    end

    defp submit_text(lv, text) do
      lv |> form("#answer-form") |> render_submit(%{"answer" => text})
    end

    test "the form is pre-filled with the stored answer and says it still counts",
         %{conn: conn, game: game, token: token} do
      lv = connect_and_restore(conn, game, token)
      submit_text(lv, "Pariss")

      lv |> element("#change-answer") |> render_click()

      assert has_element?(lv, "#editing-hint")
      assert has_element?(lv, ~s|#answer-form input[name="answer"][value="Pariss"]|)
      assert has_element?(lv, "#cancel-change")
    end

    test "cancelling returns to the confirmation without touching the answer",
         %{conn: conn, game: game, token: token, participant: participant, q1: q1} do
      lv = connect_and_restore(conn, game, token)
      submit_text(lv, "Paris")

      lv |> element("#change-answer") |> render_click()
      lv |> element("#cancel-change") |> render_click()

      refute has_element?(lv, "#answer-form")
      assert has_element?(lv, "#change-answer")
      assert Play.get_answer(participant, q1).payload["value"] == "Paris"
    end

    test "resubmitting replaces the stored answer",
         %{conn: conn, game: game, token: token, participant: participant, q1: q1} do
      lv = connect_and_restore(conn, game, token)
      submit_text(lv, "Berlin")

      lv |> element("#change-answer") |> render_click()
      submit_text(lv, "Paris")

      answer = Play.get_answer(participant, q1)
      assert answer.payload["value"] == "Paris"
      assert answer.grade == :full
      assert Play.count_answers(game, 1) == 1
    end

    test "the stored answer still counts when the host moves on mid-change",
         %{conn: conn, scope: scope, game: game, token: token, participant: participant, q1: q1} do
      lv = connect_and_restore(conn, game, token)
      submit_text(lv, "Paris")
      lv |> element("#change-answer") |> render_click()

      {:ok, _} = Play.advance_run(scope, game)

      refute has_element?(lv, "#editing-hint")
      assert Play.get_answer(participant, q1).payload["value"] == "Paris"
      assert Play.count_answers(game, 1) == 1
    end

    test "a submit for a question the host already left is rejected",
         %{conn: conn, scope: scope, game: game, token: token, participant: participant} = ctx do
      %{q1: q1, q2: q2} = ctx
      lv = connect_and_restore(conn, game, token)

      # The form was rendered for the first question, but by the time the
      # submit is processed the view has already switched to the next one.
      {:ok, _} = Play.advance_run(scope, game)

      render_submit(lv, "answer_submit", %{"question_id" => to_string(q1.id), "answer" => "0"})

      assert Play.get_answer(participant, q1) == nil
      assert Play.get_answer(participant, q2) == nil
      assert has_element?(lv, "#answer-form")
    end
  end

  describe "pre-filling the answer form" do
    test "single choice checks the stored option" do
      question = %{type: :single_choice, id: 1, data: %{choices: [%{text: "A"}, %{text: "B"}]}}
      html = render_component(&AnswerArea.answer_area/1, question: question, value: 1)
      doc = LazyHTML.from_fragment(html)

      assert [_] = doc |> LazyHTML.query(~s|input[value="1"][checked]|) |> Enum.to_list()
      assert [] = doc |> LazyHTML.query(~s|input[value="0"][checked]|) |> Enum.to_list()
    end

    test "multiple choice checks every stored option" do
      question = %{
        type: :multiple_choice,
        id: 1,
        data: %{choices: [%{text: "A"}, %{text: "B"}, %{text: "C"}]}
      }

      html = render_component(&AnswerArea.answer_area/1, question: question, value: [0, 2])
      doc = LazyHTML.from_fragment(html)

      assert doc |> LazyHTML.query("input[checked]") |> Enum.count() == 2
      assert [_] = doc |> LazyHTML.query(~s|input[value="2"][checked]|) |> Enum.to_list()
    end

    test "sequence renders the items in the stored order" do
      items = [%{id: "a", text: "First"}, %{id: "b", text: "Second"}, %{id: "c", text: "Third"}]
      question = %{type: :sequence, id: 1, data: %{items: items}}

      html =
        render_component(&AnswerArea.answer_area/1, question: question, value: ["c", "a", "b"])

      ids =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("li[data-id]")
        |> LazyHTML.attribute("data-id")

      assert ids == ["c", "a", "b"]
    end

    test "matching places stored values in their slots and leaves the rest in the pool" do
      pairs = [
        %{id: "p1", left_text: "France", right_text: "Paris"},
        %{id: "p2", left_text: "Japan", right_text: "Tokyo"}
      ]

      question = %{type: :matching, id: 1, data: %{pairs: pairs}}

      html =
        render_component(&AnswerArea.answer_area/1, question: question, value: %{"p2" => "Paris"})

      doc = LazyHTML.from_fragment(html)

      assert doc |> LazyHTML.query(~s|[data-pair-id="p2"] [data-value]|) |> LazyHTML.text() ==
               "Paris"

      assert doc |> LazyHTML.query(~s|[data-pair-id="p1"] [data-chip]|) |> Enum.count() == 0
      assert doc |> LazyHTML.query("[data-pool] [data-value]") |> LazyHTML.text() == "Tokyo"
    end
  end
end
