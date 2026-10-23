defmodule Quiz.NotifierTest do
  # Sets the global ntfy topic for the duration of each test.
  use Quiz.DataCase, async: false

  import Quiz.AccountsFixtures
  import Quiz.GamesFixtures

  alias Quiz.Accounts
  alias Quiz.Accounts.Scope

  setup do
    previous = Application.get_env(:quiz, Quiz.Notifier)
    Application.put_env(:quiz, Quiz.Notifier, Keyword.put(previous, :topic, "quiz-test"))
    on_exit(fn -> Application.put_env(:quiz, Quiz.Notifier, previous) end)

    test = self()

    Req.Test.stub(Quiz.Notifier, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:ntfy, Jason.decode!(body)})
      Req.Test.json(conn, %{})
    end)

    :ok
  end

  test "a registration is pushed to the topic" do
    user = user_fixture()

    assert_receive {:ntfy, %{"topic" => "quiz-test", "title" => "Neue Registrierung"} = push}
    assert push["message"] =~ user.name
    refute push["message"] =~ user.email
  end

  test "a guest claiming their account is pushed" do
    guest = guest_fixture()
    {:ok, user} = Accounts.claim_guest(guest, valid_user_attributes())

    assert_receive {:ntfy, %{"title" => "Gast registriert", "message" => message}}
    assert message =~ user.name
  end

  test "a quiz created by a guest is pushed" do
    game_fixture(Scope.for_user(guest_fixture()), %{title: "Pubquiz"})

    assert_receive {:ntfy, %{"title" => "Neues Gast-Quiz", "message" => message}}
    assert message =~ "Pubquiz"
  end

  test "a quiz created by a registered user is not pushed" do
    scope = user_scope_fixture()
    assert_receive {:ntfy, %{"title" => "Neue Registrierung"}}

    game_fixture(scope)

    refute_receive {:ntfy, _}
  end

  test "nothing is sent without a topic" do
    Application.put_env(
      :quiz,
      Quiz.Notifier,
      Keyword.delete(Application.get_env(:quiz, Quiz.Notifier), :topic)
    )

    user_fixture()

    refute_receive {:ntfy, _}
  end
end
