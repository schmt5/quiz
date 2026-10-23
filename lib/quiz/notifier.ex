defmodule Quiz.Notifier do
  @moduledoc """
  Pushes a short note to the operator's ntfy topic (https://ntfy.sh) when
  something worth knowing happens: a guest creates a quiz, someone registers.

  Off unless `NTFY_TOPIC` is set. Topics on ntfy.sh are readable by anyone who
  knows the name, so pick a long random one and keep personal data such as
  email addresses out of the messages. Sending runs in the background and
  failures are only logged, so a ntfy outage never affects the user.
  """

  require Logger

  alias Quiz.Accounts.User
  alias Quiz.Games.Game

  def guest_created_game(%Game{} = game) do
    notify("Neues Gast-Quiz", "Ein Gast hat „#{game.title}“ erstellt.", ["sparkles"])
  end

  def user_registered(%User{} = user) do
    notify("Neue Registrierung", "#{user.name} hat ein Konto erstellt.", ["tada"])
  end

  def guest_claimed(%User{} = user) do
    notify("Gast registriert", "Ein Gast hat sein Konto übernommen: #{user.name}.", ["tada"])
  end

  defp notify(title, message, tags) do
    config = Application.get_env(:quiz, __MODULE__, [])

    if topic = config[:topic] do
      Task.Supervisor.start_child(Quiz.TaskSupervisor, fn ->
        push(config, %{topic: topic, title: title, message: message, tags: tags})
      end)
    end

    :ok
  end

  # JSON publishing keeps umlauts intact, which plain headers would not.
  defp push(config, body) do
    url = Keyword.get(config, :url, "https://ntfy.sh")

    case Req.post(url, [json: body, retry: false] ++ Keyword.get(config, :req_options, [])) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("ntfy notification failed with status #{status}")

      {:error, reason} ->
        Logger.warning("ntfy notification failed: #{inspect(reason)}")
    end
  end
end
