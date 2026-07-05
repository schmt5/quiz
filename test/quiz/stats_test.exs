defmodule Quiz.StatsTest do
  use Quiz.DataCase

  alias Quiz.{Play, Stats}

  import Quiz.AccountsFixtures, only: [user_scope_fixture: 0]
  import Quiz.GamesFixtures

  defp running_game(scope), do: game_fixture(scope, %{status: :running})

  defp answer(game, question, name, params) do
    {:ok, participant, _token} = Play.enroll(game, name)
    {:ok, _answer} = Play.submit_answer(game, participant, question, params)
    participant
  end

  describe "single_choice" do
    test "counts per choice, most-picked first, with a blank bucket" do
      scope = user_scope_fixture()
      game = running_game(scope)

      question =
        question_fixture(scope, %{
          game_id: game.id,
          type: :single_choice,
          data: %{
            choices: [
              %{text: "A", correct: true},
              %{text: "B", correct: false},
              %{text: "C", correct: false}
            ]
          }
        })

      answer(game, question, "t1", %{"answer" => "1"})
      answer(game, question, "t2", %{"answer" => "1"})
      answer(game, question, "t3", %{"answer" => "0"})
      # A fourth team enrolls but never answers -> counts as blank.
      {:ok, _p, _tok} = Play.enroll(game, "t4")

      stats = Stats.question_stats(question, 4)

      assert stats.type == :single_choice
      assert stats.answered == 3
      assert stats.total == 4
      assert stats.blank == 1

      assert [%{label: "B", count: 2}, second, third] = stats.rows
      assert second.count == 1 and third.count == 0
      assert Enum.find(stats.rows, &(&1.label == "B")).pct == 50
    end
  end

  describe "text_input" do
    test "groups case-insensitively and labels with the most common spelling" do
      scope = user_scope_fixture()
      game = running_game(scope)
      question = question_fixture(scope, %{game_id: game.id, type: :text_input})

      answer(game, question, "t1", %{"answer" => "Paris"})
      answer(game, question, "t2", %{"answer" => "paris"})
      answer(game, question, "t3", %{"answer" => "  PARIS "})
      answer(game, question, "t4", %{"answer" => "Lyon"})
      answer(game, question, "t5", %{"answer" => ""})

      stats = Stats.question_stats(question, 5)

      assert stats.answered == 4
      assert stats.blank == 1
      assert [%{label: "Paris", count: 3, pct: 60}, %{label: "Lyon", count: 1}] = stats.rows
    end
  end

  describe "pin_on_image" do
    test "collects every valid pin as a point" do
      scope = user_scope_fixture()
      game = running_game(scope)
      question = question_fixture(scope, %{game_id: game.id, type: :pin_on_image})

      answer(game, question, "t1", %{"answer" => %{"x" => "0.2", "y" => "0.3"}})
      answer(game, question, "t2", %{"answer" => %{"x" => "0.8", "y" => "0.1"}})

      stats = Stats.question_stats(question, 2)

      assert stats.type == :pin_on_image
      assert stats.answered == 2
      assert stats.image_key == "uploads/test/fixture.png"
      assert %{x: 0.2, y: 0.3} in stats.points
      assert length(stats.points) == 2
    end
  end

  describe "number_range" do
    test "collects integer guesses, the bounds and the average" do
      scope = user_scope_fixture()
      game = running_game(scope)
      question = question_fixture(scope, %{game_id: game.id, type: :number_range})

      answer(game, question, "t1", %{"answer" => "340"})
      answer(game, question, "t2", %{"answer" => "360"})
      answer(game, question, "t3", %{"answer" => "500"})
      # A blank / unparseable answer is dropped, not counted.
      answer(game, question, "t4", %{"answer" => ""})
      {:ok, _p, _tok} = Play.enroll(game, "t5")

      stats = Stats.question_stats(question, 5)

      assert stats.type == :number_range
      assert stats.answered == 3
      assert stats.total == 5
      assert stats.blank == 2
      assert stats.min == 10
      assert stats.max == 700
      assert Enum.sort(stats.points) == [340, 360, 500]
      assert stats.average == 400
    end

    test "average is nil when nobody guessed" do
      scope = user_scope_fixture()
      game = running_game(scope)
      question = question_fixture(scope, %{game_id: game.id, type: :number_range})

      stats = Stats.question_stats(question, 0)

      assert stats.answered == 0
      assert stats.points == []
      assert is_nil(stats.average)
    end
  end

  describe "sequence" do
    test "groups identical orderings, most common first, labelled by item text" do
      scope = user_scope_fixture()
      game = running_game(scope)
      question = question_fixture(scope, %{game_id: game.id, type: :sequence})

      [a, b, c] = Enum.map(question.data.items, & &1.id)
      correct = Enum.join([a, b, c], ",")
      swapped = Enum.join([b, a, c], ",")

      answer(game, question, "t1", %{"answer" => correct})
      answer(game, question, "t2", %{"answer" => correct})
      answer(game, question, "t3", %{"answer" => swapped})

      stats = Stats.question_stats(question, 3)

      assert stats.type == :sequence
      assert stats.answered == 3
      assert stats.more == 0
      assert [%{labels: ["First", "Second", "Third"], count: 2}, %{count: 1}] = stats.rows
    end
  end

  describe "matching" do
    test "shows the per-left distribution of chosen right-sides" do
      scope = user_scope_fixture()
      game = running_game(scope)
      question = question_fixture(scope, %{game_id: game.id, type: :matching})

      [france | _] = question.data.pairs
      pick = fn right -> %{"answer" => Jason.encode!(%{to_string(france.id) => right})} end

      answer(game, question, "t1", pick.("Paris"))
      answer(game, question, "t2", pick.("Paris"))
      answer(game, question, "t3", pick.("Tokyo"))

      stats = Stats.question_stats(question, 3)

      assert stats.type == :matching
      france_row = Enum.find(stats.pairs, &(&1.left == "France"))
      assert [%{label: "Paris", count: 2}, %{label: "Tokyo", count: 1}] = france_row.rows
    end
  end

  test "no answers yields zeroed stats" do
    scope = user_scope_fixture()
    game = running_game(scope)
    question = question_fixture(scope, %{game_id: game.id, type: :single_choice})

    stats = Stats.question_stats(question, 0)
    assert stats.answered == 0
    assert stats.blank == 0
  end
end
