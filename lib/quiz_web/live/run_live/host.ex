defmodule QuizWeb.RunLive.Host do
  @moduledoc """
  Operator "landing page" for a running quiz (the lobby). Shows the join code,
  a QR code linking to the enrollment page, and the live list of enrolled teams.
  From here the operator starts the quiz.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:h-screen lg:overflow-hidden bg-base-100">
      <%!-- Left 2/3: title, QR + code, primary action --%>
      <div class="lg:w-2/3 flex flex-col items-center justify-center gap-8 p-8 lg:overflow-y-auto">
        <div class="text-center space-y-1">
          <p class="font-mono text-xs uppercase tracking-wider text-base-content/60">
            Mach mit beim Quiz
          </p>
          <h1 class="text-3xl sm:text-4xl font-bold">{@game.title}</h1>
        </div>

        <div :if={@game.status == :open} class="flex flex-col items-center gap-4">
          <div class="bg-white rounded-3xl shadow-xl ring-1 ring-base-300 p-6">
            <div class="size-56 sm:size-64">{raw(@qr_svg)}</div>
          </div>
          <div class="text-center">
            <p class="text-sm text-base-content/60">Code</p>
            <p class="font-mono text-4xl font-bold tracking-[0.3em] pl-[0.3em]">
              {@game.join_code}
            </p>
          </div>
        </div>

        <div :if={@game.status == :running} class="text-center space-y-2">
          <.icon name="hero-bolt" class="size-12 text-primary" />
          <p class="text-xl font-bold">Das Quiz läuft.</p>
        </div>

        <button
          :if={@game.status == :open}
          type="button"
          phx-click="start"
          disabled={@participants == []}
          class="btn btn-primary btn-lg"
        >
          <.icon name="hero-play" /> Quiz starten
        </button>

        <.link navigate={~p"/games/#{@game}"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Zurück zum Quiz
        </.link>
      </div>

      <%!-- Right 1/3: full-height, self-scrolling team roster --%>
      <aside class="lg:w-1/3 flex flex-col min-h-0 bg-base-200 border-t lg:border-t-0 lg:border-l border-base-300">
        <div class="shrink-0 flex items-baseline justify-between p-6 border-b border-base-300">
          <h2 class="text-lg font-bold">Teams</h2>
          <span class="badge badge-primary badge-lg font-mono">{length(@participants)}</span>
        </div>

        <p
          :if={@participants == []}
          class="p-6 text-center text-sm text-base-content/60"
        >
          Warte auf die ersten Teams …
        </p>

        <ul id="participants" class="flex-1 min-h-0 overflow-y-auto p-6 space-y-2 list-none">
          <li
            :for={participant <- @participants}
            id={"participant-#{participant.id}"}
            class="flex items-center gap-2 rounded-box bg-base-100 px-3 py-2"
          >
            <.icon name="hero-user-group" class="size-4 text-base-content/50" />
            <span class="text-sm font-medium truncate">{participant.name}</span>
          </li>
        </ul>
      </aside>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)

    if connected?(socket), do: Play.subscribe(game)

    {:ok,
     socket
     |> assign(:page_title, "Durchführung: #{game.title}")
     |> assign(:game, game)
     |> assign(:qr_svg, qr_svg(game))
     |> assign(:participants, Play.list_participants(game))}
  end

  @impl true
  def handle_event("start", _params, socket) do
    case Play.start_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} ->
        {:noreply, assign(socket, :game, game)}

      {:error, :no_questions} ->
        {:noreply, put_flash(socket, :error, "Dieses Quiz hat noch keine Fragen.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Das Quiz konnte nicht gestartet werden.")}
    end
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    {:noreply, assign(socket, :participants, socket.assigns.participants ++ [participant])}
  end

  def handle_info({:status_changed, game}, socket) do
    {:noreply, assign(socket, :game, game)}
  end

  defp qr_svg(game) do
    (QuizWeb.Endpoint.url() <> ~p"/join?code=#{game.join_code}")
    |> EQRCode.encode()
    |> EQRCode.svg(viewbox: true, class: "w-full h-full", color: "#000000")
  end
end
