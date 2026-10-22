defmodule Quiz.Accounts.GuestCleanup do
  @moduledoc """
  Deletes expired guest accounts together with everything they own: first all
  uploads under the guest's storage prefix (R2 in production), then the user
  row, which cascades to its quizzes, questions, participants, answers and
  corrections.

  Runs hourly (and shortly after boot). Each pass is safe to repeat and to run
  on several machines at once: a guest whose files could not be deleted is kept
  and retried on the next pass, and a guest with a quiz that is open or running
  right now is left alone until it is over.
  """
  use GenServer

  import Ecto.Query
  require Logger

  alias Quiz.{Accounts, Repo, Storage}
  alias Quiz.Accounts.User
  alias Quiz.Games.Game

  @interval :timer.hours(1)
  @first_run :timer.minutes(1)

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @interval)
    Process.send_after(self(), :run, Keyword.get(opts, :first_run, @first_run))
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:run, state) do
    result = run()

    if result != %{deleted: 0, postponed: 0, failed: 0},
      do: Logger.info("Guest cleanup: #{inspect(result)}")

    Process.send_after(self(), :run, state.interval)
    {:noreply, state}
  end

  @doc """
  One cleanup pass over the guests expired at `now`. Returns how many were
  `deleted`, `postponed` (a quiz is live) or `failed` (files could not be
  removed; retried next pass).
  """
  def run(now \\ DateTime.utc_now()) do
    now
    |> Accounts.list_expired_guests()
    |> Enum.reduce(%{deleted: 0, postponed: 0, failed: 0}, fn user, counts ->
      Map.update!(counts, delete_guest(user), &(&1 + 1))
    end)
  end

  defp delete_guest(%User{} = user) do
    cond do
      live_quiz?(user) ->
        :postponed

      not still_expired_guest?(user) ->
        # Claimed (registered) since the list was loaded — keep everything.
        :postponed

      true ->
        case Storage.delete_prefix(Storage.user_prefix(user.id)) do
          :ok ->
            Repo.delete_all(from(u in User, where: u.id == ^user.id and u.guest))
            :deleted

          {:error, reason} ->
            Logger.warning(
              "Guest cleanup: could not delete files of user #{user.id}: #{inspect(reason)}"
            )

            :failed
        end
    end
  end

  defp live_quiz?(user) do
    Repo.exists?(from(g in Game, where: g.user_id == ^user.id and g.status in [:open, :running]))
  end

  defp still_expired_guest?(user) do
    Repo.exists?(
      from(u in User, where: u.id == ^user.id and u.guest and u.expires_at < ^DateTime.utc_now())
    )
  end
end
