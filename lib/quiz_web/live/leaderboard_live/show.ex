defmodule QuizWeb.LeaderboardLive.Show do
  @moduledoc """
  The leaderboard (presenter screen). Until the corrector publishes the grading
  it shows a "Korrektur in Bearbeitung" placeholder; on publish it swaps live to
  the final standings.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play}
  alias QuizWeb.LeaderboardComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 flex flex-col items-center p-6 sm:p-10">
      <div class="w-full max-w-xl space-y-8">
        <div class="text-center space-y-1">
          <p class="text-xs uppercase tracking-wider text-base-content/60">Rangliste</p>
          <h1 class="text-3xl sm:text-4xl font-bold">{@game.title}</h1>
        </div>

        <div
          :if={!@game.grading_published}
          class="flex flex-col items-center gap-4 rounded-3xl bg-base-200 p-10 text-center"
        >
          <span class="loading loading-dots loading-lg text-primary"></span>
          <p class="text-xl font-bold">Korrektur in Bearbeitung</p>
          <p class="text-base-content/60">
            Die Rangliste erscheint, sobald die Wertung veröffentlicht ist.
          </p>
        </div>

        <LeaderboardComponent.standings :if={@game.grading_published} rows={@rows} />
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)
    if connected?(socket), do: Play.subscribe(game)

    {:ok,
     socket
     |> assign(:page_title, "Rangliste: #{game.title}")
     |> assign(:game, game)
     |> assign_rows()}
  end

  @impl true
  def handle_info({:grading_published, game}, socket) do
    {:noreply, socket |> assign(:game, game) |> assign_rows()}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_rows(socket) do
    rows =
      if socket.assigns.game.grading_published,
        do: Play.leaderboard(socket.assigns.game),
        else: []

    assign(socket, :rows, rows)
  end
end
