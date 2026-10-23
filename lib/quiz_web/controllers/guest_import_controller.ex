defmodule QuizWeb.GuestImportController do
  @moduledoc """
  Receives the AI import form (`QuizWeb.GameLive.Import`) from a visitor without
  an account: creates a guest account, imports the quiz into it and logs the
  guest in. Lives in a controller because only a regular request can set the
  session cookie.
  """
  use QuizWeb, :controller

  alias Quiz.{Accounts, Games, RateLimit, Repo}
  alias Quiz.Accounts.Scope
  alias Quiz.Games.TextFormat
  alias QuizWeb.UserAuth

  def create(conn, %{"import" => %{"text" => text} = params}) do
    cond do
      conn.assigns.current_scope ->
        # Already signed in (e.g. a second tab): the LiveView path handles this.
        redirect(conn, to: ~p"/erstellen")

      not Accounts.guest_mode_enabled?() ->
        conn
        |> put_flash(:error, "Bitte melde dich an, um ein Quiz zu erstellen.")
        |> redirect(to: ~p"/users/log-in")

      true ->
        create_guest_quiz(conn, text, QuizWeb.GameLive.Import.settings_from_params(params))
    end
  end

  defp create_guest_quiz(conn, text, settings) do
    {limit, window} = Application.get_env(:quiz, :guest_rate_limit, {10, :timer.hours(1)})

    with :ok <- RateLimit.hit({:guest, client_ip(conn)}, limit, window),
         {:ok, parsed} <- TextFormat.parse(text),
         {:ok, {user, game, first}} <- import_as_guest(parsed, settings) do
      conn
      |> put_flash(:info, "Quiz erstellt. Prüfe die Fragen und ergänze, was noch fehlt.")
      |> put_session(:user_return_to, ~p"/games/#{game}/questions/#{first}/edit")
      |> UserAuth.log_in_user(user, %{"remember_me" => "true"})
    else
      {:error, :rate_limited} ->
        conn
        |> put_flash(
          :error,
          "Von deinem Netzwerk wurden gerade viele Gastzugänge erstellt. Versuch es später nochmals oder erstelle ein Konto."
        )
        |> redirect(to: ~p"/erstellen")

      _error ->
        conn
        |> put_flash(
          :error,
          "Das Quiz konnte nicht angelegt werden. Bitte füge die Antwort der KI nochmals ein."
        )
        |> redirect(to: ~p"/erstellen")
    end
  end

  # The guest only exists together with its quiz: if the import fails, so does
  # the account.
  defp import_as_guest(parsed, settings) do
    Repo.transaction(fn ->
      with {:ok, user} <- Accounts.create_guest(),
           scope = Scope.for_user(user),
           {:ok, game} <- Games.import_game(scope, parsed, settings) do
        [first | _] = Games.list_questions_for_game(scope, game)
        {user, game, first}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # Fly's proxy passes the visitor's address in this header; locally (and
  # without a proxy) the socket peer is the visitor.
  defp client_ip(conn) do
    case get_req_header(conn, "fly-client-ip") do
      [ip | _] -> ip
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
