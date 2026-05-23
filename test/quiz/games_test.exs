defmodule Quiz.GamesTest do
  use Quiz.DataCase

  alias Quiz.Games

  describe "games" do
    alias Quiz.Games.Game

    import Quiz.AccountsFixtures, only: [user_scope_fixture: 0]
    import Quiz.GamesFixtures

    @invalid_attrs %{status: nil, title: nil}
    @join_code_format ~r/^[A-HJ-NP-Z2-9]{6}$/

    test "list_games/1 returns all scoped games" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)
      other_game = game_fixture(other_scope)
      assert Games.list_games(scope) == [game]
      assert Games.list_games(other_scope) == [other_game]
    end

    test "get_game!/2 returns the game with given id" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      other_scope = user_scope_fixture()
      assert Games.get_game!(scope, game.id) == game
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(other_scope, game.id) end
    end

    test "create_game/2 with valid data creates a game with an auto-generated join_code" do
      valid_attrs = %{status: :draft, title: "some title"}
      scope = user_scope_fixture()

      assert {:ok, %Game{} = game} = Games.create_game(scope, valid_attrs)
      assert game.status == :draft
      assert game.title == "some title"
      assert game.join_code =~ @join_code_format
      assert game.user_id == scope.user.id
    end

    test "create_game/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.create_game(scope, @invalid_attrs)
    end

    test "update_game/3 with valid data updates the game and preserves join_code" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      original_join_code = game.join_code
      update_attrs = %{status: :open, title: "some updated title"}

      assert {:ok, %Game{} = updated_game} = Games.update_game(scope, game, update_attrs)
      assert updated_game.status == :open
      assert updated_game.title == "some updated title"
      assert updated_game.join_code == original_join_code
    end

    test "update_game/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)

      assert_raise MatchError, fn ->
        Games.update_game(other_scope, game, %{})
      end
    end

    test "update_game/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Games.update_game(scope, game, @invalid_attrs)
      assert game == Games.get_game!(scope, game.id)
    end

    test "delete_game/2 deletes the game" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      assert {:ok, %Game{}} = Games.delete_game(scope, game)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(scope, game.id) end
    end

    test "delete_game/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)
      assert_raise MatchError, fn -> Games.delete_game(other_scope, game) end
    end

    test "change_game/2 returns a game changeset" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      assert %Ecto.Changeset{} = Games.change_game(scope, game)
    end
  end

  describe "questions" do
    alias Quiz.Games.Question

    import Quiz.AccountsFixtures, only: [user_scope_fixture: 0]
    import Quiz.GamesFixtures

    @invalid_attrs %{position: nil, type: nil, prompt: nil}

    test "list_questions/1 returns all scoped questions" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      question = question_fixture(scope)
      other_question = question_fixture(other_scope)
      assert Games.list_questions(scope) == [question]
      assert Games.list_questions(other_scope) == [other_question]
    end

    test "get_question!/2 returns the question with given id" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      other_scope = user_scope_fixture()
      assert Games.get_question!(scope, question.id) == question
      assert_raise Ecto.NoResultsError, fn -> Games.get_question!(other_scope, question.id) end
    end

    test "create_question/2 with valid single_choice data creates a question" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      valid_attrs = %{
        type: :single_choice,
        prompt: "some prompt",
        position: 42,
        game_id: game.id,
        data: %{
          choices: [
            %{text: "A", correct: true},
            %{text: "B", correct: false}
          ]
        }
      }

      assert {:ok, %Question{} = question} = Games.create_question(scope, valid_attrs)
      assert question.position == 42
      assert question.type == :single_choice
      assert question.prompt == "some prompt"
      assert question.user_id == scope.user.id
      assert [%{text: "A", correct: true}, %{text: "B", correct: false}] = question.data.choices
      assert question.data.solutions == []
    end

    test "create_question/2 with text_input trims and stores multiple solutions" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      attrs = %{
        type: :text_input,
        prompt: "Capital of France?",
        position: 1,
        game_id: game.id,
        data: %{
          solutions: [%{text: "Paris"}, %{text: "  PARIS  "}]
        }
      }

      assert {:ok, %Question{} = question} = Games.create_question(scope, attrs)
      assert Enum.map(question.data.solutions, & &1.text) == ["Paris", "PARIS"]
      assert question.data.choices == []
    end

    test "create_question/2 requires exactly one correct choice for single_choice" do
      scope = user_scope_fixture()

      no_correct = %{
        type: :single_choice,
        prompt: "?",
        position: 1,
        data: %{choices: [%{text: "A", correct: false}, %{text: "B", correct: false}]}
      }

      assert {:error, changeset} = Games.create_question(scope, no_correct)
      assert %{data: %{choices: [_ | _]}} = errors_on(changeset)

      too_many_correct =
        put_in(no_correct, [:data, :choices], [
          %{text: "A", correct: true},
          %{text: "B", correct: true}
        ])

      assert {:error, _} = Games.create_question(scope, too_many_correct)
    end

    test "create_question/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.create_question(scope, @invalid_attrs)
    end

    test "update_question/3 type switch discards previous data" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      assert length(question.data.choices) == 2

      update_attrs = %{
        type: :text_input,
        prompt: "now text",
        position: 43,
        data: %{solutions: [%{text: "Paris"}]}
      }

      assert {:ok, %Question{} = updated} = Games.update_question(scope, question, update_attrs)
      assert updated.type == :text_input
      assert updated.data.choices == []
      assert Enum.map(updated.data.solutions, & &1.text) == ["Paris"]
    end

    test "Question.correct_answer?/2 — text_input is case-insensitive and trimmed" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      {:ok, q} =
        Games.create_question(scope, %{
          type: :text_input,
          prompt: "?",
          position: 1,
          game_id: game.id,
          data: %{solutions: [%{text: "Paris"}]}
        })

      assert Quiz.Games.Question.correct_answer?(q, "  paris ")
      assert Quiz.Games.Question.correct_answer?(q, "PARIS")
      refute Quiz.Games.Question.correct_answer?(q, "London")
    end

    test "Question.correct_answer?/2 — single_choice checks the chosen index" do
      scope = user_scope_fixture()
      q = question_fixture(scope)

      assert Quiz.Games.Question.correct_answer?(q, 0)
      refute Quiz.Games.Question.correct_answer?(q, 1)
      refute Quiz.Games.Question.correct_answer?(q, 99)
    end

    test "Question.correct_answer?/2 — sequence compares ordered item ids" do
      scope = user_scope_fixture()
      q = question_fixture(scope, %{type: :sequence})

      ordered_ids = Enum.map(q.data.items, & &1.id)
      [a, b, c] = ordered_ids

      assert Quiz.Games.Question.correct_answer?(q, ordered_ids)
      refute Quiz.Games.Question.correct_answer?(q, [b, a, c])
      refute Quiz.Games.Question.correct_answer?(q, [a, b])
      refute Quiz.Games.Question.correct_answer?(q, "not a list")
    end

    test "update_question/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      question = question_fixture(scope)

      assert_raise MatchError, fn ->
        Games.update_question(other_scope, question, %{})
      end
    end

    test "update_question/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Games.update_question(scope, question, @invalid_attrs)
      assert question == Games.get_question!(scope, question.id)
    end

    test "delete_question/2 deletes the question" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      assert {:ok, %Question{}} = Games.delete_question(scope, question)
      assert_raise Ecto.NoResultsError, fn -> Games.get_question!(scope, question.id) end
    end

    test "delete_question/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      question = question_fixture(scope)
      assert_raise MatchError, fn -> Games.delete_question(other_scope, question) end
    end

    test "change_question/2 returns a question changeset" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      assert %Ecto.Changeset{} = Games.change_question(scope, question)
    end

    test "reposition_questions/3 rewrites positions to match the given order" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      q1 = question_fixture(scope, %{game_id: game.id, position: 1, prompt: "first"})
      q2 = question_fixture(scope, %{game_id: game.id, position: 2, prompt: "second"})
      q3 = question_fixture(scope, %{game_id: game.id, position: 3, prompt: "third"})

      assert :ok = Games.reposition_questions(scope, game, [q3.id, q1.id, q2.id])

      assert [
               %{id: id3, position: 1},
               %{id: id1, position: 2},
               %{id: id2, position: 3}
             ] = Games.list_questions_for_game(scope, game)

      assert id3 == q3.id
      assert id1 == q1.id
      assert id2 == q2.id
    end

    test "reposition_questions/3 broadcasts :reordered" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      q1 = question_fixture(scope, %{game_id: game.id, position: 1})
      q2 = question_fixture(scope, %{game_id: game.id, position: 2})

      Games.subscribe_questions(scope)
      assert :ok = Games.reposition_questions(scope, game, [q2.id, q1.id])

      assert_receive {:reordered, ^game}
    end

    test "reposition_questions/3 rejects ids that do not match the game" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      q1 = question_fixture(scope, %{game_id: game.id, position: 1})
      other_game = game_fixture(scope)
      stranger = question_fixture(scope, %{game_id: other_game.id, position: 1})

      assert {:error, :invalid} =
               Games.reposition_questions(scope, game, [q1.id, stranger.id])

      assert [%{id: id, position: 1}] = Games.list_questions_for_game(scope, game)
      assert id == q1.id
    end

    test "reposition_questions/3 rejects when an id is missing from the order" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      q1 = question_fixture(scope, %{game_id: game.id, position: 1})
      _q2 = question_fixture(scope, %{game_id: game.id, position: 2})

      assert {:error, :invalid} = Games.reposition_questions(scope, game, [q1.id])
    end

    test "reposition_questions/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)
      q1 = question_fixture(scope, %{game_id: game.id, position: 1})
      q2 = question_fixture(scope, %{game_id: game.id, position: 2})

      assert_raise MatchError, fn ->
        Games.reposition_questions(other_scope, game, [q2.id, q1.id])
      end
    end
  end
end
