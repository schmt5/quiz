defmodule Quiz.Presence do
  @moduledoc """
  Tracks live participant connections per game. Lives in the core app (not
  `QuizWeb`) because `Quiz.Play` consults it to decide whether a team may be
  rebound by name.
  """
  use Phoenix.Presence,
    otp_app: :quiz,
    pubsub_server: Quiz.PubSub
end
