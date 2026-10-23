defmodule Quiz.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        QuizWeb.Telemetry,
        Quiz.Repo,
        {DNSCluster, query: Application.get_env(:quiz, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Quiz.PubSub},
        Quiz.RateLimit,
        # Fire-and-forget work such as `Quiz.Notifier` pushes.
        {Task.Supervisor, name: Quiz.TaskSupervisor}
      ] ++
        guest_cleanup() ++
        [
          # Start to serve requests, typically the last entry
          QuizWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quiz.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Deleting expired guests is off in tests, which run a pass explicitly.
  defp guest_cleanup do
    if Application.get_env(:quiz, Quiz.Accounts.GuestCleanup, [])[:enabled] == false,
      do: [],
      else: [Quiz.Accounts.GuestCleanup]
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuizWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
