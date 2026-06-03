defmodule Quiz.PlayTest do
  use Quiz.DataCase

  alias Quiz.Play
  alias Quiz.Play.Participant

  import Quiz.AccountsFixtures, only: [user_scope_fixture: 0]
  import Quiz.GamesFixtures

  describe "open_run/2" do
    test "moves a draft game to :open and broadcasts" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})
      Play.subscribe(game)

      assert {:ok, %{status: :open} = opened} = Play.open_run(scope, game)
      assert_received {:status_changed, %{id: id, status: :open}}
      assert id == opened.id
    end

    test "rejects an invalid transition (running -> open)" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})

      assert {:error, changeset} = Play.open_run(scope, game)
      assert %{status: [_]} = errors_on(changeset)
    end

    test "refuses a game owned by another user" do
      scope = user_scope_fixture()
      other = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})

      assert_raise MatchError, fn -> Play.open_run(other, game) end
    end
  end

  describe "start_run/2" do
    test "moves :open to :running and parks on the first question" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 5})
      question_fixture(scope, %{game_id: game.id, position: 9})

      assert {:ok, %{status: :running, current_position: 5}} = Play.start_run(scope, game)
    end

    test "rejects a quiz without questions" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert {:error, :no_questions} = Play.start_run(scope, game)
    end
  end

  describe "get_game_by_join_code/1" do
    test "finds a joinable game case-insensitively" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert {:ok, found} = Play.get_game_by_join_code(String.downcase(game.join_code))
      assert found.id == game.id
    end

    test "does not return a draft game" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})

      assert {:error, :not_found} = Play.get_game_by_join_code(game.join_code)
    end

    test "returns :not_found for an unknown code" do
      assert {:error, :not_found} = Play.get_game_by_join_code("ZZZZZZ")
    end
  end

  describe "enroll/2 and restore_participant/2" do
    test "enrolls a team, broadcasts and round-trips the token" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      Play.subscribe(game)

      assert {:ok, %Participant{name: "Team A"} = participant, token} =
               Play.enroll(game, "Team A")

      assert_received {:participant_joined, %{name: "Team A"}}
      assert {:ok, restored} = Play.restore_participant(game, token)
      assert restored.id == participant.id
    end

    test "allows enrollment while the quiz is already running" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})

      assert {:ok, %Participant{}, _token} = Play.enroll(game, "Latecomer")
    end

    test "rejects enrollment for a non-joinable game" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :finished})

      assert {:error, :not_joinable} = Play.enroll(game, "Too Late")
    end

    test "rejects a duplicate team name within the same game" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert {:ok, _p, _t} = Play.enroll(game, "Dup")
      assert {:error, changeset} = Play.enroll(game, "Dup")
      assert %{name: [_]} = errors_on(changeset)
    end

    test "rejects a token from a different game" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      other_game = game_fixture(scope, %{status: :open})

      assert {:ok, _p, token} = Play.enroll(game, "Team A")
      assert {:error, :invalid} = Play.restore_participant(other_game, token)
    end

    test "rejects a garbage token" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert {:error, :invalid} = Play.restore_participant(game, "not-a-token")
    end
  end

  describe "list_participants/1 and current_question/1" do
    test "lists enrolled teams oldest first" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      {:ok, _, _} = Play.enroll(game, "First")
      {:ok, _, _} = Play.enroll(game, "Second")

      assert ["First", "Second"] = Enum.map(Play.list_participants(game), & &1.name)
    end

    test "current_question/1 returns the question at the current position" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 3, prompt: "Q at 3"})

      {:ok, running} = Play.start_run(scope, game)

      assert %{prompt: "Q at 3"} = Play.current_question(running)
    end

    test "current_question/1 is nil before a run starts" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert is_nil(Play.current_question(game))
    end

    test "question_numbering/1 returns the 1-based ordinal and total" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 5})
      question_fixture(scope, %{game_id: game.id, position: 9})
      question_fixture(scope, %{game_id: game.id, position: 12})

      {:ok, running} = Play.start_run(scope, game)
      assert {1, 3} = Play.question_numbering(running)

      assert {2, 3} = Play.question_numbering(%{running | current_position: 9})
    end

    test "question_numbering/1 is {0, 0} before a run starts" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert {0, 0} = Play.question_numbering(game)
    end
  end
end
