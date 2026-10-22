defmodule QuizWeb.PageController do
  use QuizWeb, :controller

  def home(conn, _params) do
    guest_mode = Quiz.Accounts.guest_mode_enabled?()

    conn
    |> assign(:guest_mode, guest_mode)
    |> assign(:create_path, if(guest_mode, do: ~p"/erstellen", else: ~p"/users/register"))
    |> render(:home)
  end

  def sponsors(conn, _params) do
    render(conn, :sponsors)
  end
end
