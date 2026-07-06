defmodule QuizWeb.PageController do
  use QuizWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def sponsors(conn, _params) do
    render(conn, :sponsors)
  end
end
