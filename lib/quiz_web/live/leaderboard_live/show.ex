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
    <div class="flex flex-col h-screen overflow-hidden bg-base-100">
      <%!-- Header (brand · title · primary action), mirroring the run view. --%>
      <div class="shrink-0 flex items-center justify-between gap-4 h-[84px] px-6 border-b border-base-300">
        <div class="flex items-center gap-4 min-w-0">
          <.link
            navigate={~p"/"}
            class="inline-flex items-baseline text-2xl font-extrabold tracking-tight shrink-0"
          >
            <span class="text-primary">Pub</span>
            <span class="bg-primary text-secondary rounded-xl px-2 py-0.5">Quiz</span>
          </.link>
          <div class="min-w-0">
            <h1 class="text-lg font-bold truncate">{@game.title}</h1>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
              Rangliste
            </p>
          </div>
        </div>

        <.link navigate={~p"/games/#{@game}"} class="btn btn-primary shrink-0">
          <.icon name="hero-arrow-left" /> Zurück zum Quiz
        </.link>
      </div>

      <div class="flex-1 min-h-0 overflow-y-auto flex flex-col items-center p-6 sm:p-10">
        <div class="w-full max-w-xl space-y-8">
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
