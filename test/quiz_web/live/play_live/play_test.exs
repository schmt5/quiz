defmodule QuizWeb.PlayLive.PlayTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  alias Quiz.Play

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

    test "renders the uploaded video for a video question", %{conn: conn} do
      %{game: game, token: token} =
        start_running_game(%{media_video_key: "uploads/1/clip.mp4"})

      lv = connect_and_restore(conn, game, token)

      html = render(lv)
      assert html =~ ~s|<video src="#{Quiz.Storage.url("uploads/1/clip.mp4")}"|
      assert html =~ ~s|preload="none"|
    end
  end
end
