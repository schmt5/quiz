defmodule Quiz.GamesTest do
  use Quiz.DataCase

  alias Quiz.Games

  describe "games" do
    alias Quiz.Games.Game

    import Quiz.AccountsFixtures, only: [user_scope_fixture: 0]
    import Quiz.GamesFixtures

    @invalid_attrs %{status: nil, title: nil}
    @join_code_format ~r/^[1-9]\d{3}$/

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
      valid_attrs = %{title: "some title"}
      scope = user_scope_fixture()

      assert {:ok, %Game{} = game} = Games.create_game(scope, valid_attrs)
      assert game.status == :draft
      assert game.title == "some title"
      assert game.join_code =~ @join_code_format
      assert game.user_id == scope.user.id
    end

    test "create_game/2 always starts in :draft and ignores a supplied status" do
      scope = user_scope_fixture()

      assert {:ok, %Game{} = game} =
               Games.create_game(scope, %{title: "some title", status: :running})

      assert game.status == :draft
    end

    test "create_game/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.create_game(scope, @invalid_attrs)
    end

    test "create_game/2 generates distinct join codes across many games" do
      scope = user_scope_fixture()

      codes =
        for _ <- 1..25 do
          assert {:ok, %Game{join_code: code}} =
                   Games.create_game(scope, %{title: "t"})

          code
        end

      assert length(Enum.uniq(codes)) == length(codes)
    end

    test "update_game/3 with valid data updates the game and preserves join_code" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      original_join_code = game.join_code
      update_attrs = %{title: "some updated title"}

      assert {:ok, %Game{} = updated_game} = Games.update_game(scope, game, update_attrs)
      assert updated_game.status == :draft
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

    test "delete_game/2 deletes a game together with its questions" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      question = question_fixture(scope, %{game_id: game.id})

      assert {:ok, %Game{}} = Games.delete_game(scope, game)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(scope, game.id) end
      assert_raise Ecto.NoResultsError, fn -> Games.get_question!(scope, question.id) end
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

    test "duplicate_game/2 copies the game and all questions into a fresh draft" do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{title: "Original"})

      q1 =
        question_fixture(scope, %{
          game_id: game.id,
          position: 1,
          type: :text_input,
          prompt: "Hauptstadt von Frankreich?",
          data: %{solutions: [%{text: "Paris"}]}
        })

      q2 =
        question_fixture(scope, %{
          game_id: game.id,
          position: 2,
          type: :matching,
          prompt: "Ordne zu",
          data: %{
            pairs: [
              %{left_text: "Frankreich", right_text: "Paris"},
              %{left_text: "Japan", right_text: "Tokio"}
            ]
          }
        })

      # Questions are authored while the game is a draft; only then is the run
      # finished (questions can no longer be edited once it is).
      game = set_game_status(game, :finished)

      assert {:ok, copy} = Games.duplicate_game(scope, game)

      # Fresh draft with a new identity but a copied title.
      assert copy.id != game.id
      assert copy.title == "Original (Kopie)"
      assert copy.status == :draft
      assert copy.grading_published == false
      assert copy.join_code != game.join_code
      assert copy.user_id == scope.user.id

      # All questions copied, in order, with their answer payload intact.
      copied = Games.list_questions_for_game(scope, copy)
      assert length(copied) == 2
      [c1, c2] = copied

      assert c1.id != q1.id
      assert c1.prompt == "Hauptstadt von Frankreich?"
      assert c1.type == :text_input
      assert Enum.map(c1.data.solutions, & &1.text) == ["Paris"]

      assert c2.id != q2.id
      assert c2.type == :matching

      assert Enum.map(c2.data.pairs, &{&1.left_text, &1.right_text}) ==
               [{"Frankreich", "Paris"}, {"Japan", "Tokio"}]

      # The original is untouched.
      assert length(Games.list_questions_for_game(scope, game)) == 2
    end

    test "duplicate_game/2 refuses a game owned by someone else" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      game = game_fixture(scope)

      assert_raise MatchError, fn -> Games.duplicate_game(other_scope, game) end
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

    test "create_question/3 creates a blank skeleton without a prompt or data" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      assert {:ok, %Question{} = question} =
               Games.create_question(scope, game, :single_choice)

      assert question.type == :single_choice
      assert question.prompt in [nil, ""]
      assert question.game_id == game.id
      assert question.user_id == scope.user.id
    end

    test "create_question/3 appends after the game's existing questions" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      question_fixture(scope, %{game_id: game.id, position: 5})

      assert {:ok, %Question{position: 6}} = Games.create_question(scope, game, :text_input)
    end

    test "a skeleton must be completed (prompt required) before it can be updated" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      {:ok, question} = Games.create_question(scope, game, :single_choice)

      # The strict edit changeset still requires a prompt and valid answer data.
      assert {:error, %Ecto.Changeset{} = changeset} =
               Games.update_question(scope, question, %{"prompt" => ""})

      assert "can't be blank" in errors_on(changeset).prompt
    end

    test "create_question/2 stores a sanitized description" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      attrs = %{
        type: :single_choice,
        prompt: "some prompt",
        position: 1,
        game_id: game.id,
        description:
          ~s|<strong>bold</strong> <em>it</em> <mark class="hl-yellow">hi</mark>| <>
            ~s|<a href="x" onclick="evil()">link</a><script>alert(1)</script>|,
        data: %{choices: [%{text: "A", correct: true}, %{text: "B", correct: false}]}
      }

      assert {:ok, %Question{} = question} = Games.create_question(scope, attrs)
      # Allowed formatting survives...
      assert question.description =~ "<strong>bold</strong>"
      assert question.description =~ "<em>it</em>"
      assert question.description =~ ~s(<mark class="hl-yellow">hi</mark>)
      # ...dangerous markup is stripped (only inner text remains).
      refute question.description =~ "<script"
      refute question.description =~ "onclick"
      refute question.description =~ "<a "
      assert question.description =~ "link"
    end

    test "create_question/2 leaves a blank description untouched" do
      scope = user_scope_fixture()
      game = game_fixture(scope)
      question = question_fixture(scope, game_id: game.id)
      assert question.description == nil
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

    test "create_question/2 with valid matching data stores pairs and clears others" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      attrs = %{
        type: :matching,
        prompt: "Match countries to capitals",
        position: 1,
        game_id: game.id,
        data: %{
          pairs: [
            %{left_text: "France", right_text: "Paris"},
            %{left_text: "  Japan ", right_text: "  Tokyo "}
          ]
        }
      }

      assert {:ok, %Question{} = question} = Games.create_question(scope, attrs)
      assert question.type == :matching
      assert Enum.map(question.data.pairs, & &1.left_text) == ["France", "Japan"]
      assert Enum.map(question.data.pairs, & &1.right_text) == ["Paris", "Tokyo"]
      assert question.data.choices == []
      assert question.data.pin == nil
    end

    test "create_question/2 requires at least two pairs for matching" do
      scope = user_scope_fixture()

      attrs = %{
        type: :matching,
        prompt: "?",
        position: 1,
        data: %{pairs: [%{left_text: "France", right_text: "Paris"}]}
      }

      assert {:error, changeset} = Games.create_question(scope, attrs)
      assert %{data: %{pairs: [_ | _]}} = errors_on(changeset)
    end

    test "create_question/2 rejects duplicate right_text in matching" do
      scope = user_scope_fixture()

      attrs = %{
        type: :matching,
        prompt: "?",
        position: 1,
        data: %{
          pairs: [
            %{left_text: "France", right_text: "Paris"},
            %{left_text: "Frankreich", right_text: "paris"}
          ]
        }
      }

      assert {:error, changeset} = Games.create_question(scope, attrs)
      assert %{data: %{pairs: [_ | _]}} = errors_on(changeset)
    end

    test "update_question/3 switching to matching clears other embeds" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      assert length(question.data.choices) == 2

      update_attrs = %{
        type: :matching,
        prompt: "now matching",
        position: 43,
        data: %{
          pairs: [
            %{left_text: "France", right_text: "Paris"},
            %{left_text: "Japan", right_text: "Tokyo"}
          ]
        }
      }

      assert {:ok, %Question{} = updated} = Games.update_question(scope, question, update_attrs)
      assert updated.type == :matching
      assert updated.data.choices == []
      assert Enum.map(updated.data.pairs, & &1.left_text) == ["France", "Japan"]
    end

    test "Question.correct_answer?/2 and score_answer/2 — matching scores per pair" do
      scope = user_scope_fixture()
      q = question_fixture(scope, %{type: :matching})
      [france, japan, brazil] = q.data.pairs

      all_correct = %{
        france.id => "Paris",
        japan.id => "Tokyo",
        brazil.id => "Brasília"
      }

      assert Quiz.Games.Question.score_answer(q, all_correct) == {3, 3}
      assert Quiz.Games.Question.correct_answer?(q, all_correct)

      # case-insensitive + trimmed, one wrong
      partial = %{
        france.id => "  paris ",
        japan.id => "Kyoto",
        brazil.id => "Brasília"
      }

      assert Quiz.Games.Question.score_answer(q, partial) == {2, 3}
      refute Quiz.Games.Question.correct_answer?(q, partial)

      assert Quiz.Games.Question.score_answer(q, %{}) == {0, 3}
      refute Quiz.Games.Question.correct_answer?(q, "not a map")
    end

    test "create_question/2 with pin_on_image stores and clamps the pin" do
      scope = user_scope_fixture()
      game = game_fixture(scope)

      attrs = %{
        type: :pin_on_image,
        prompt: "Wo liegt Paris?",
        position: 1,
        game_id: game.id,
        data: %{
          pin: %{image_key: "uploads/u/map.png", target_x: 1.4, target_y: -0.2, radius: 0.1}
        }
      }

      assert {:ok, %Question{} = question} = Games.create_question(scope, attrs)
      assert question.type == :pin_on_image
      assert question.data.pin.image_key == "uploads/u/map.png"
      assert question.data.pin.target_x == 1.0
      assert question.data.pin.target_y == 0.0
      assert question.data.choices == []
    end

    test "create_question/2 requires an image_key for pin_on_image" do
      scope = user_scope_fixture()

      attrs = %{
        type: :pin_on_image,
        prompt: "?",
        position: 1,
        data: %{pin: %{target_x: 0.5, target_y: 0.5, radius: 0.1}}
      }

      assert {:error, changeset} = Games.create_question(scope, attrs)
      assert %{data: %{pin: %{image_key: [_ | _]}}} = errors_on(changeset)
    end

    test "update_question/3 switching to pin_on_image clears other embeds" do
      scope = user_scope_fixture()
      question = question_fixture(scope)
      assert length(question.data.choices) == 2

      update_attrs = %{
        type: :pin_on_image,
        prompt: "now pin",
        position: 43,
        data: %{pin: %{image_key: "uploads/u/x.png", target_x: 0.3, target_y: 0.7, radius: 0.2}}
      }

      assert {:ok, %Question{} = updated} = Games.update_question(scope, question, update_attrs)
      assert updated.type == :pin_on_image
      assert updated.data.choices == []
      assert updated.data.pin.target_x == 0.3
    end

    test "update_question/3 switching away from pin_on_image clears the pin" do
      scope = user_scope_fixture()
      question = question_fixture(scope, %{type: :pin_on_image})
      assert question.data.pin

      update_attrs = %{
        type: :text_input,
        prompt: "now text",
        position: 1,
        data: %{solutions: [%{text: "Paris"}]}
      }

      assert {:ok, %Question{} = updated} = Games.update_question(scope, question, update_attrs)
      assert updated.type == :text_input
      assert updated.data.pin == nil
    end

    test "Question.correct_answer?/2 — pin_on_image scores by distance to the target" do
      scope = user_scope_fixture()
      q = question_fixture(scope, %{type: :pin_on_image})
      # fixture target is 0.5/0.5 with radius 0.1

      assert Quiz.Games.Question.correct_answer?(q, %{"x" => 0.5, "y" => 0.5})
      assert Quiz.Games.Question.correct_answer?(q, %{"x" => 0.52, "y" => 0.48})
      # exactly on the boundary (distance == radius) counts as correct
      assert Quiz.Games.Question.correct_answer?(q, %{"x" => 0.6, "y" => 0.5})
      refute Quiz.Games.Question.correct_answer?(q, %{"x" => 0.7, "y" => 0.7})
      refute Quiz.Games.Question.correct_answer?(q, %{"x" => 0.5})
      refute Quiz.Games.Question.correct_answer?(q, "not a map")
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

    for status <- [:finished, :closed] do
      @tag status: status
      test "create_question/2 is rejected once the run is #{status}", %{status: status} do
        scope = user_scope_fixture()
        game = game_fixture(scope) |> set_game_status(status)

        attrs = %{
          game_id: game.id,
          type: :single_choice,
          prompt: "Neue Frage",
          position: 1,
          data: %{choices: [%{text: "A", correct: true}, %{text: "B", correct: false}]}
        }

        assert {:error, :run_locked} = Games.create_question(scope, attrs)
      end

      @tag status: status
      test "update_question/3 is rejected once the run is #{status}", %{status: status} do
        scope = user_scope_fixture()
        game = game_fixture(scope)
        question = question_fixture(scope, %{game_id: game.id, position: 1})
        set_game_status(game, status)

        assert {:error, :run_locked} =
                 Games.update_question(scope, question, %{prompt: "geändert"})
      end

      @tag status: status
      test "delete_question/2 is rejected once the run is #{status}", %{status: status} do
        scope = user_scope_fixture()
        game = game_fixture(scope)
        question = question_fixture(scope, %{game_id: game.id, position: 1})
        set_game_status(game, status)

        assert {:error, :run_locked} = Games.delete_question(scope, question)
        assert %Question{} = Games.get_question!(scope, question.id)
      end

      @tag status: status
      test "reposition_questions/3 is rejected once the run is #{status}", %{status: status} do
        scope = user_scope_fixture()
        game = game_fixture(scope)
        q1 = question_fixture(scope, %{game_id: game.id, position: 1})
        q2 = question_fixture(scope, %{game_id: game.id, position: 2})
        game = set_game_status(game, status)

        assert {:error, :run_locked} =
                 Games.reposition_questions(scope, game, [q2.id, q1.id])
      end
    end

    test "questions can still be edited while the run is open or running" do
      scope = user_scope_fixture()

      for status <- [:draft, :open, :running] do
        game = game_fixture(scope)
        question = question_fixture(scope, %{game_id: game.id, position: 1})
        set_game_status(game, status)

        new_prompt = "ok-#{status}"

        assert {:ok, %Question{} = updated} =
                 Games.update_question(scope, question, %{prompt: new_prompt})

        assert updated.prompt == new_prompt
      end
    end
  end
end
