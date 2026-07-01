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
end
