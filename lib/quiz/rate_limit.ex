defmodule Quiz.RateLimit do
  @moduledoc """
  A small fixed-window rate limiter on a public ETS table, e.g. to cap how many
  guest accounts one network creates per hour.

  Counts are per node. That is deliberate: it only needs to stop casual abuse,
  and if it is not enough the guest mode can be switched off (`GUEST_MODE`).
  """
  use GenServer

  @table __MODULE__
  @sweep_every :timer.minutes(10)

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Records a hit for `key` and returns `:ok` while at most `limit` hits fall into
  the current window of `window_ms`, `{:error, :rate_limited}` beyond that.
  """
  def hit(key, limit, window_ms) do
    now = System.system_time(:millisecond)
    window = div(now, window_ms)
    entry = {key, window}
    expires_at = (window + 1) * window_ms

    case :ets.update_counter(@table, entry, {2, 1}, {entry, 0, expires_at}) do
      count when count <= limit -> :ok
      _count -> {:error, :rate_limited}
    end
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)
end
