defmodule QuizWeb.PlayLive.JoinTest do
  use QuizWeb.ConnCase

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  defp open_game(_context) do
    scope = user_scope_fixture()
    %{game: game_fixture(scope, %{status: :open})}
  end

  describe "joining with feedback" do
    setup :open_game

    test "an unknown code shows a clear error naming the code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: "0000"})
        |> render_submit()

      assert html =~ "Kein Quiz mit der PIN"
      assert html =~ "0000"
    end

    test "an empty code asks for the code", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: ""})
        |> render_submit()

      assert html =~ "Bitte gib die PIN ein"
    end

    test "the error clears once the participant edits the form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: "0000"})
        |> render_submit()

      assert html =~ "Kein Quiz mit der PIN"

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: "000"})
        |> render_change()

      refute html =~ "Kein Quiz mit der PIN"
    end

    test "a valid PIN for a not-yet-opened quiz says so, not 'wrong PIN'",
         %{conn: conn} do
      scope = user_scope_fixture()
      draft = game_fixture(scope, %{status: :draft})

      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: draft.join_code})
        |> render_submit()

      assert html =~ "wurde noch nicht gestartet"
      refute html =~ "Kein Quiz mit der PIN"
    end

    test "a valid PIN for a finished quiz says it has ended", %{conn: conn} do
      scope = user_scope_fixture()
      done = game_fixture(scope, %{status: :finished})

      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: done.join_code})
        |> render_submit()

      assert html =~ "bereits beendet"
      refute html =~ "Kein Quiz mit der PIN"
    end

    test "an existing team can reconnect to a finished quiz to see results",
         %{conn: conn} do
      scope = user_scope_fixture()
      game = game_fixture(scope, %{status: :open})
      {:ok, _p, _t} = Quiz.Play.enroll(game, "Team A")
      {:ok, done} = game |> Ecto.Changeset.change(status: :finished) |> Quiz.Repo.update()

      {:ok, lv, _html} = live(conn, ~p"/join")

      lv
      |> form("#join-form", participant: %{name: "Team A", code: done.join_code})
      |> render_submit()

      assert_redirect(lv, ~p"/play/#{done.join_code}")
    end

    test "a valid code enrols and moves to the waiting room", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/join")

      lv
      |> form("#join-form", participant: %{name: "Team A", code: game.join_code})
      |> render_submit()

      assert_redirect(lv, ~p"/play/#{game.join_code}")
    end
  end

  describe "seat takeover protection" do
    setup :open_game

    test "the name of a connected team cannot be taken over", %{conn: conn, game: game} do
      {:ok, _p, token} = Quiz.Play.enroll(game, "Team A")

      # Browser 1: live in the play view (the JS hook restores the token).
      {:ok, play_lv, _html} = live(conn, ~p"/play/#{game.join_code}")
      render_hook(play_lv, "restore_participant", %{"token" => token})

      # Browser 2: tries to enroll under the same name.
      {:ok, lv, _html} = live(conn, ~p"/join")

      html =
        lv
        |> form("#join-form", participant: %{name: "Team A", code: game.join_code})
        |> render_submit()

      assert html =~ "bereits vergeben"
    end

    test "an offline team can rejoin by retyping its name", %{conn: conn, game: game} do
      {:ok, _p, _t} = Quiz.Play.enroll(game, "Team A")

      {:ok, lv, _html} = live(conn, ~p"/join")

      lv
      |> form("#join-form", participant: %{name: "Team A", code: game.join_code})
      |> render_submit()

      assert_redirect(lv, ~p"/play/#{game.join_code}")
    end
  end

  describe "resuming a stored team" do
    setup :open_game

    test "a held token forwards straight to the waiting room", %{conn: conn, game: game} do
      {:ok, _p, token} = Quiz.Play.enroll(game, "Team A")

      {:ok, lv, html} = live(conn, ~p"/join?code=#{game.join_code}")
      # Arriving with a code, we hold on the spinner rather than flashing the form.
      assert html =~ "Verbinde"

      render_hook(lv, "try_resume", %{"token" => token})
      assert_redirect(lv, ~p"/play/#{game.join_code}")
    end

    test "no stored token drops to the join form", %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/join?code=#{game.join_code}")

      html = render_hook(lv, "no_resume", %{})
      assert html =~ "Teamname"
    end

    test "a stale/invalid token drops to the join form without redirecting",
         %{conn: conn, game: game} do
      {:ok, lv, _html} = live(conn, ~p"/join?code=#{game.join_code}")

      html = render_hook(lv, "try_resume", %{"token" => "not-a-real-token"})
      assert html =~ "Teamname"
    end
  end
end
