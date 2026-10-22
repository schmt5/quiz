defmodule QuizWeb.UserLive.RegistrationTest do
  use QuizWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Quiz.AccountsFixtures

  describe "registration page" do
    test "renders the registration form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      assert has_element?(lv, "#registration_form")
      assert has_element?(lv, "#registration-login-link[href='/users/log-in']")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")

      assert {:error, {:redirect, _}} = result
    end

    test "renders validation errors on change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert html =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates the account and logs it in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form =
        form(lv, "#registration_form",
          user: %{name: "Neue Quizmasterin", email: email, password: valid_user_password()}
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Willkommen"

      user = Quiz.Accounts.get_user_by_email(email)
      assert user.name == "Neue Quizmasterin"
      refute user.admin
    end

    test "renders errors for a taken email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture()

      html =
        lv
        |> form("#registration_form",
          user: %{name: "Jemand", email: user.email, password: valid_user_password()}
        )
        |> render_submit()

      assert html =~ "ist bereits vergeben"
    end
  end

  describe "claiming a guest account" do
    setup %{conn: conn} do
      guest = guest_fixture()
      %{conn: log_in_user(conn, guest), guest: guest}
    end

    test "offers the guest to keep its quizzes", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Quizze behalten"
      refute has_element?(lv, "#registration-login-link")
    end

    test "turns the guest into a regular account", %{conn: conn, guest: guest} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      {:ok, conn} =
        lv
        |> form("#registration_form",
          user: %{name: "Lehrerin", email: email, password: valid_user_password()}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/games")

      assert html_response(conn, 200) =~ "Konto ist erstellt"

      user = Quiz.Accounts.get_user!(guest.id)
      refute user.guest
      assert user.email == email
    end
  end
end
