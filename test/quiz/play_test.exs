defmodule Quiz.PlayTest do
  use Quiz.DataCase

  alias Quiz.Play
  alias Quiz.Play.{Participant, Answer}
  alias Quiz.Repo

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

    test "opens a draft game whose questions are all complete" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})
      question_fixture(scope, %{game_id: game.id, position: 1})

      assert {:ok, %{status: :open}} = Play.open_run(scope, game)
    end

    test "refuses to open a draft game with an incomplete question" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})
      question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, skeleton} = Quiz.Games.create_question(scope, game, :single_choice)

      assert {:error, {:incomplete_questions, [incomplete]}} = Play.open_run(scope, game)
      assert incomplete.id == skeleton.id

      # The transition did not happen.
      assert Quiz.Games.get_game!(scope, game.id).status == :draft
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

      assert {:ok, %{status: :running, current_position: 5, revealing: false}} =
               Play.start_run(scope, game)
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

    test "reports a draft game as :not_started (valid PIN, not opened yet)" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})

      assert {:error, :not_started} = Play.get_game_by_join_code(game.join_code)
    end

    test "reports a finished/closed game as :ended (valid PIN, over)" do
      scope = user_scope_fixture()

      for status <- [:finished, :closed] do
        game = game_fixture(scope, %{status: status})
        assert {:error, :ended} = Play.get_game_by_join_code(game.join_code)
      end
    end

    test "returns :not_found for an unknown code" do
      assert {:error, :not_found} = Play.get_game_by_join_code("ZZZZZZ")
    end
  end

  describe "get_game_for_play/1" do
    test "resolves a finished game (so a reloading team sees the end screen)" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :finished})

      # The joinable lookup rejects it (as :ended), but the play lookup still finds it.
      assert {:error, :ended} = Play.get_game_by_join_code(game.join_code)
      assert {:ok, found} = Play.get_game_for_play(String.downcase(game.join_code))
      assert found.id == game.id
    end

    test "resolves open, running and closed games too" do
      scope = user_scope_fixture()

      for status <- [:open, :running, :closed] do
        game = game_fixture(scope, %{status: status})
        assert {:ok, found} = Play.get_game_for_play(game.join_code)
        assert found.id == game.id
      end
    end

    test "does not resolve a draft game (no run yet)" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :draft})

      assert {:error, :not_found} = Play.get_game_for_play(game.join_code)
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

    test "enrolling with an existing team name is refused" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      # Names are strictly first come, first serve — only the stored token
      # gets a team back in, never retyping the name.
      assert {:ok, %Participant{id: id}, _t} = Play.enroll(game, "Dup")
      assert {:error, :name_taken} = Play.enroll(game, "Dup")
      assert [%Participant{id: ^id}] = Play.list_participants(game)
    end

    test "an existing name is refused ignoring surrounding whitespace" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})

      assert {:ok, %Participant{id: id}, _t} = Play.enroll(game, "Trimmed")
      assert {:error, :name_taken} = Play.enroll(game, "  Trimmed  ")
      assert [%Participant{id: ^id}] = Play.list_participants(game)
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

  describe "reveal_run/2" do
    test "keeps the run on the same question but flips :revealing on" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open, review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 5})
      {:ok, running} = Play.start_run(scope, game)
      Play.subscribe(running)

      assert {:ok, %{status: :running, current_position: 5, revealing: true}} =
               Play.reveal_run(scope, running)

      assert_received {:status_changed, %{revealing: true}}
    end
  end

  describe "advance_run/2" do
    test "moves to the next question's position" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 5})
      question_fixture(scope, %{game_id: game.id, position: 9})
      {:ok, running} = Play.start_run(scope, game)
      Play.subscribe(running)

      assert {:ok, %{status: :running, current_position: 9}} = Play.advance_run(scope, running)
      assert_received {:status_changed, %{current_position: 9}}
    end

    test "clears :revealing when advancing past a revealed question" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open, review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 5})
      question_fixture(scope, %{game_id: game.id, position: 9})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, revealed} = Play.reveal_run(scope, running)

      assert {:ok, %{status: :running, current_position: 9, revealing: false}} =
               Play.advance_run(scope, revealed)
    end

    test "finishes the run after the last question" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 5})
      {:ok, running} = Play.start_run(scope, game)

      assert {:ok, %{status: :finished}} = Play.advance_run(scope, running)
    end

    test "finishes with :revealing cleared after the last question's reveal" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open, review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 5})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, revealed} = Play.reveal_run(scope, running)

      assert {:ok, %{status: :finished, revealing: false}} = Play.advance_run(scope, revealed)
    end
  end

  describe "retreat_run/2" do
    test "moves back to the previous question's position" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 5})
      question_fixture(scope, %{game_id: game.id, position: 9})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, advanced} = Play.advance_run(scope, running)
      Play.subscribe(advanced)

      assert {:ok, %{status: :running, current_position: 5}} = Play.retreat_run(scope, advanced)
      assert_received {:status_changed, %{current_position: 5}}
    end

    test "clears :revealing when retreating from a revealed question" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open, review_mode: :per_question})
      question_fixture(scope, %{game_id: game.id, position: 5})
      question_fixture(scope, %{game_id: game.id, position: 9})
      {:ok, running} = Play.start_run(scope, game)
      {:ok, advanced} = Play.advance_run(scope, running)
      {:ok, revealed} = Play.reveal_run(scope, advanced)

      assert {:ok, %{status: :running, current_position: 5, revealing: false}} =
               Play.retreat_run(scope, revealed)
    end

    test "is a no-op on the first question" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      question_fixture(scope, %{game_id: game.id, position: 5})
      {:ok, running} = Play.start_run(scope, game)

      assert {:ok, %{status: :running, current_position: 5}} = Play.retreat_run(scope, running)
    end
  end

  describe "submit_answer/4, get_answer/2 and count_answers/2" do
    test "scores and stores a correct single-choice answer" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})
      question = question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, participant, _t} = Play.enroll(game, "Team A")
      Play.subscribe(game)

      assert {:ok, %Answer{grade: :full, payload: %{"value" => 0}}} =
               Play.submit_answer(game, participant, question, %{"answer" => "0"})

      assert_received {:answer_submitted, 1}
      assert Play.get_answer(participant, question).grade == :full
      assert Play.count_answers(game, 1) == 1
    end

    test "resubmitting upserts the same row (latest wins)" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})
      question = question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, participant, _t} = Play.enroll(game, "Team A")

      assert {:ok, _} = Play.submit_answer(game, participant, question, %{"answer" => "1"})
      assert Play.get_answer(participant, question).grade == :zero

      assert {:ok, _} = Play.submit_answer(game, participant, question, %{"answer" => "0"})
      assert Play.get_answer(participant, question).grade == :full
      assert Repo.aggregate(Answer, :count) == 1
    end

    test "scores a text_input answer, trimmed and case-insensitive" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})
      question = question_fixture(scope, %{game_id: game.id, position: 1, type: :text_input})
      {:ok, participant, _t} = Play.enroll(game, "Team A")

      assert {:ok, %Answer{grade: :full}} =
               Play.submit_answer(game, participant, question, %{"answer" => "  paris "})
    end

    test "rejects answers once the question is revealed" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running, revealing: true})
      question = question_fixture(scope, %{game_id: game.id, position: 1})
      {:ok, participant, _t} = Play.enroll(game, "Team A")

      assert {:error, :not_accepting_answers} =
               Play.submit_answer(game, participant, question, %{"answer" => "0"})

      assert Play.count_answers(game, 1) == 0
    end

    test "count_answers/2 is 0 before any answer" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})
      question_fixture(scope, %{game_id: game.id, position: 1})

      assert Play.count_answers(game, 1) == 0
    end
  end

  describe "auto_grade/2" do
    test "matching earns full, half, or zero" do
      scope = user_scope_fixture()
      q = question_fixture(scope, %{type: :matching, position: 1})
      [p1, p2, p3] = Enum.map(q.data.pairs, & &1.id)
      [r1, r2, r3] = Enum.map(q.data.pairs, & &1.right_text)

      assert Play.auto_grade(q, %{p1 => r1, p2 => r2, p3 => r3}) == :full
      assert Play.auto_grade(q, %{p1 => r1, p2 => r2, p3 => "wrong"}) == :half
      assert Play.auto_grade(q, %{p1 => "x", p2 => "y", p3 => "z"}) == :zero
    end
  end

  describe "bulk correction" do
    setup do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})
      question = question_fixture(scope, %{game_id: game.id, position: 1, type: :text_input})

      teams =
        for name <- ~w(A B C D), into: %{} do
          {:ok, p, _t} = Play.enroll(game, name)
          {name, p}
        end

      %{scope: scope, game: game, question: question, teams: teams}
    end

    test "group_answers buckets identical answers, most common first, blanks last",
         %{game: game, question: q, teams: teams} do
      Play.submit_answer(game, teams["A"], q, %{"answer" => "Paris"})
      Play.submit_answer(game, teams["B"], q, %{"answer" => "paris"})
      Play.submit_answer(game, teams["C"], q, %{"answer" => "Berlin"})
      Play.submit_answer(game, teams["D"], q, %{"answer" => "   "})

      groups = Play.group_answers(q, Play.list_answers_for_question(q))

      assert [paris, berlin, blank] = groups
      assert paris.count == 2
      assert MapSet.new(paris.participants) == MapSet.new(["A", "B"])
      assert paris.grade == :full
      assert berlin.count == 1
      assert blank.blank
      assert blank.count == 1
    end

    test "grade_group sets every answer in the group", %{game: game, question: q, teams: teams} do
      Play.submit_answer(game, teams["A"], q, %{"answer" => "Berlin"})
      Play.submit_answer(game, teams["B"], q, %{"answer" => "berlin"})

      [group] = Play.group_answers(q, Play.list_answers_for_question(q))
      assert {:ok, 2} = Play.grade_group(group.answer_ids, :half)

      assert Play.get_answer(teams["A"], q).grade == :half
      assert Play.get_answer(teams["B"], q).grade == :half
    end

    test "mark_question_done and correction_overview", %{game: game, question: q, teams: teams} do
      Play.submit_answer(game, teams["A"], q, %{"answer" => "Paris"})

      refute Play.correction_done?(q)

      assert [%{question: ^q, answer_count: 1, done: false, gradable: true}] =
               Play.correction_overview(game)

      assert {:ok, _} = Play.mark_question_done(q)
      assert Play.correction_done?(q)
      assert [%{done: true}] = Play.correction_overview(game)
    end
  end

  describe "publish_grading/2 and leaderboard/1" do
    test "publish sets the flag and broadcasts" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :finished})
      Play.subscribe(game)

      assert {:ok, %{grading_published: true}} = Play.publish_grading(scope, game)
      assert_received {:grading_published, %{grading_published: true}}
    end

    test "leaderboard sums points and ranks, ties shared" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :running})
      q1 = question_fixture(scope, %{game_id: game.id, position: 1})
      q2 = question_fixture(scope, %{game_id: game.id, position: 2})

      {:ok, winner, _} = Play.enroll(game, "Winner")
      {:ok, mid_a, _} = Play.enroll(game, "MidA")
      {:ok, mid_b, _} = Play.enroll(game, "MidB")

      # single_choice fixture: index 0 is correct (full), 1 is wrong (zero)
      Play.submit_answer(game, winner, q1, %{"answer" => "0"})
      Play.submit_answer(game, winner, q2, %{"answer" => "0"})
      Play.submit_answer(game, mid_a, q1, %{"answer" => "0"})
      Play.submit_answer(game, mid_b, q1, %{"answer" => "0"})

      assert [
               %{participant: %{name: "Winner"}, score: 2.0, rank: 1},
               %{score: 1.0, rank: 2},
               %{score: 1.0, rank: 2}
             ] = Play.leaderboard(game)
    end
  end
end
