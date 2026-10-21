defmodule Quiz.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :quiz

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Grants operator access (LiveDashboard) to the user with the given email:

      bin/quiz eval 'Quiz.Release.grant_admin("me@example.com")'
  """
  def grant_admin(email) do
    load_app()

    # Only the repo, not the whole app: a full start would also try to boot the
    # endpoint next to the already running release.
    {:ok, result, _} =
      Ecto.Migrator.with_repo(Quiz.Repo, fn _repo ->
        case Quiz.Accounts.get_user_by_email(email) do
          nil -> {:error, :not_found}
          user -> Quiz.Accounts.set_admin(user, true)
        end
      end)

    result
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
