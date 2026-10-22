defmodule Quiz.GuestsTest do
  # The cleanup deletes files from the shared local storage directory.
  use Quiz.DataCase, async: false

  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  alias Quiz.{Accounts, Games, RateLimit, Storage}
  alias Quiz.Accounts.{GuestCleanup, Scope, User}

  defp past, do: DateTime.add(DateTime.utc_now(:second), -60)

  describe "create_guest/0" do
    test "creates a password-less account that expires after the guest lifetime" do
      assert {:ok, %User{} = guest} = Accounts.create_guest()

      assert Accounts.guest?(guest)
      refute Accounts.admin?(guest)
      assert guest.email =~ "@gast.invalid"
      assert is_nil(guest.hashed_password)

      days = DateTime.diff(guest.expires_at, DateTime.utc_now(), :day)
      assert days in (Accounts.guest_lifetime_days() - 1)..Accounts.guest_lifetime_days()
    end

    test "cannot log in with a password" do
      guest = guest_fixture()
      refute Accounts.get_user_by_email_and_password(guest.email, "")
    end
  end

  describe "claim_guest/2" do
    test "turns the guest into a regular account that keeps its quizzes" do
      guest = guest_fixture()
      game = game_fixture(Scope.for_user(guest))

      assert {:ok, user} =
               Accounts.claim_guest(guest, %{
                 name: "Lehrerin",
                 email: "lehrerin@example.com",
                 password: valid_user_password()
               })

      refute user.guest
      assert is_nil(user.expires_at)
      assert user.id == guest.id

      assert Accounts.get_user_by_email_and_password(
               "lehrerin@example.com",
               valid_user_password()
             )

      assert [%{id: id}] = Games.list_games(Scope.for_user(user))
      assert id == game.id
    end

    test "validates like a registration" do
      guest = guest_fixture()
      taken = user_fixture()

      assert {:error, changeset} =
               Accounts.claim_guest(guest, %{name: "X", email: taken.email, password: "kurz"})

      assert %{email: [_], password: [_]} = errors_on(changeset)
      assert Accounts.guest?(Repo.get!(User, guest.id))
    end
  end

  describe "guest quiz limit" do
    test "a guest holds at most guest_max_games quizzes" do
      scope = Scope.for_user(guest_fixture())

      for _ <- 1..Games.guest_max_games(), do: game_fixture(scope)

      assert Games.guest_limit_reached?(scope)
      assert {:error, changeset} = Games.create_game(scope, %{title: "Eins zu viel"})
      assert %{title: [message]} = errors_on(changeset)
      assert message =~ "höchstens"

      {:ok, parsed} = Games.TextFormat.parse("Quiz: X\nFrage: A?\nTyp: Texteingabe\nLösung: a")
      assert {:error, _} = Games.import_game(scope, parsed)

      [game | _] = Games.list_games(scope)
      assert {:error, _} = Games.duplicate_game(scope, game)
    end

    test "does not apply to regular accounts" do
      scope = user_scope_fixture()
      for _ <- 1..(Games.guest_max_games() + 1), do: game_fixture(scope)

      refute Games.guest_limit_reached?(scope)
    end
  end

  describe "GuestCleanup.run/1" do
    defp upload_for(user) do
      source = Path.join(System.tmp_dir!(), "guest_#{System.unique_integer([:positive])}.png")
      File.write!(source, "png")
      {:ok, key} = Storage.put(Scope.for_user(user), source, filename: "bild.png")
      File.rm!(source)

      dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
      Path.join(dir, Path.relative_to(key, "uploads"))
    end

    test "deletes expired guests with their quizzes and uploads" do
      guest = guest_fixture(%{expires_at: past()})
      scope = Scope.for_user(guest)
      game = game_fixture(scope)
      question_fixture(scope, %{game_id: game.id})
      file = upload_for(guest)

      assert %{deleted: 1} = GuestCleanup.run()

      refute Repo.get(User, guest.id)
      refute Repo.get(Games.Game, game.id)
      refute File.exists?(file)
    end

    test "keeps guests that have not expired, regular users and claimed guests" do
      active = guest_fixture()
      user = user_fixture()

      claimed = guest_fixture(%{expires_at: past()})
      {:ok, _} = Accounts.claim_guest(claimed, valid_user_attributes())

      file = upload_for(user)
      on_exit(fn -> Storage.delete_prefix(Storage.user_prefix(user.id)) end)

      assert %{deleted: 0} = GuestCleanup.run()

      assert Repo.get(User, active.id)
      assert Repo.get(User, user.id)
      assert Repo.get(User, claimed.id)
      assert File.exists?(file)
    end

    test "waits while a guest's quiz is live" do
      guest = guest_fixture(%{expires_at: past()})
      game = game_fixture(Scope.for_user(guest), %{status: :running})

      assert %{postponed: 1, deleted: 0} = GuestCleanup.run()
      assert Repo.get(User, guest.id)

      set_game_status(game, :finished)
      assert %{deleted: 1} = GuestCleanup.run()
    end
  end

  describe "RateLimit.hit/3" do
    test "allows `limit` hits per window and refuses the rest" do
      key = {:test, System.unique_integer()}

      assert :ok = RateLimit.hit(key, 2, :timer.hours(1))
      assert :ok = RateLimit.hit(key, 2, :timer.hours(1))
      assert {:error, :rate_limited} = RateLimit.hit(key, 2, :timer.hours(1))

      assert :ok = RateLimit.hit({:test, System.unique_integer()}, 2, :timer.hours(1))
    end
  end
end
