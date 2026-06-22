defmodule QuizWeb.GameLive.Index do
  use QuizWeb, :live_view

  alias Quiz.Games

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl space-y-6">
        <div class="flex items-end justify-between gap-4">
          <div>
            <div class="breadcrumbs text-xs">
              <ul>
                <li>
                  <.link navigate={~p"/"} aria-label="Home">
                    <.icon name="hero-home" class="size-4" />
                  </.link>
                </li>
                <li>Quizze</li>
              </ul>
            </div>
            <h1 class="text-2xl sm:text-3xl font-bold">Meine Quizze</h1>
            <p class="mt-1 text-sm text-base-content/55">
              {count_label(@games_count)}
            </p>
          </div>
          <.link navigate={~p"/games/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="size-5" /> Neues Quiz
          </.link>
        </div>

        <div
          :if={@games_count == 0}
          class="rounded-box border border-dashed border-base-300 bg-base-200/40 p-12 text-center"
        >
          <span class="mx-auto flex size-14 items-center justify-center rounded-2xl bg-primary/15 text-primary">
            <.icon name="hero-rectangle-stack" class="size-7" />
          </span>
          <h2 class="mt-4 text-lg font-bold">Noch keine Quizze</h2>
          <p class="mt-1 text-sm text-base-content/55">
            Erstelle dein erstes Quiz und lege mit der ersten Frage los.
          </p>
          <.link navigate={~p"/games/new"} class="btn btn-primary mt-6">
            <.icon name="hero-plus" class="size-5" /> Erstes Quiz erstellen
          </.link>
        </div>

        <ul
          :if={@games_count > 0}
          id="games"
          phx-update="stream"
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
        >
          <li
            :for={{id, game} <- @streams.games}
            id={id}
            class="group relative flex flex-col rounded-box border border-base-200 bg-base-100 p-5 shadow-sm transition hover:border-base-300 hover:shadow-md"
          >
            <div class="flex items-start justify-between gap-3">
              <.status_badge status={game.status} />
              <button
                type="button"
                popovertarget={"game-menu-#{game.id}"}
                class="btn btn-ghost btn-xs btn-square -mr-1 -mt-1 relative z-10 text-base-content/50"
                style={"anchor-name:--game-menu-#{game.id}"}
                aria-label="Weitere Aktionen"
              >
                <.icon name="hero-ellipsis-vertical" class="size-5" />
              </button>
              <ul
                class="dropdown dropdown-end menu w-48 rounded-box bg-base-100 shadow-lg border border-base-200"
                popover
                id={"game-menu-#{game.id}"}
                style={"position-anchor:--game-menu-#{game.id}"}
              >
                <li>
                  <.link navigate={~p"/games/#{game}/edit"}>
                    <.icon name="hero-pencil-square" class="size-4" /> Bearbeiten
                  </.link>
                </li>
                <li>
                  <.link
                    phx-click={JS.push("delete", value: %{id: game.id}) |> hide("##{id}")}
                    data-confirm="Dieses Quiz wirklich löschen?"
                    class="text-error"
                  >
                    <.icon name="hero-trash" class="size-4" /> Löschen
                  </.link>
                </li>
              </ul>
            </div>

            <.link navigate={~p"/games/#{game}"} class="mt-3 flex-1">
              <h2 class="text-lg font-bold leading-tight line-clamp-2 group-hover:text-primary transition">
                {game.title}
              </h2>
              <span class="absolute inset-0" aria-hidden="true"></span>
            </.link>

            <div class="mt-4 flex items-center justify-between border-t border-base-200 pt-3">
              <div>
                <p class="text-[0.65rem] font-medium uppercase tracking-wider text-base-content/45">
                  PIN
                </p>
                <p class="font-mono text-lg font-bold tracking-[0.2em]">{game.join_code}</p>
              </div>
              <span class="relative z-10 inline-flex items-center gap-1 text-sm font-medium text-base-content/45 transition group-hover:text-primary">
                Öffnen <.icon name="hero-arrow-right" class="size-4" />
              </span>
            </div>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={["badge badge-soft gap-1.5", status_class(@status)]}>
      <span
        :if={@status == :running}
        class="inline-block size-1.5 rounded-full bg-current animate-pulse"
      >
      </span>
      {status_label(@status)}
    </span>
    """
  end

  defp status_label(:draft), do: "Entwurf"
  defp status_label(:open), do: "Offen"
  defp status_label(:running), do: "Läuft"
  defp status_label(:finished), do: "Beendet"
  defp status_label(:closed), do: "Geschlossen"
  defp status_label(other), do: to_string(other)

  defp status_class(:draft), do: "badge-neutral"
  defp status_class(:open), do: "badge-info"
  defp status_class(:running), do: "badge-success"
  defp status_class(:finished), do: "badge-warning"
  defp status_class(:closed), do: "badge-neutral"
  defp status_class(_), do: "badge-neutral"

  defp count_label(0), do: "Noch keine Quizze erstellt."
  defp count_label(1), do: "1 Quiz"
  defp count_label(n), do: "#{n} Quizze"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Games.subscribe_games(socket.assigns.current_scope)
    end

    games = list_games(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Quizze")
     |> assign(:games_count, length(games))
     |> stream(:games, games)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)
    {:ok, _} = Games.delete_game(socket.assigns.current_scope, game)

    {:noreply,
     socket
     |> update(:games_count, &max(&1 - 1, 0))
     |> stream_delete(:games, game)}
  end

  @impl true
  def handle_info({type, %Quiz.Games.Game{}}, socket)
      when type in [:created, :updated, :deleted] do
    games = list_games(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:games_count, length(games))
     |> stream(:games, games, reset: true)}
  end

  defp list_games(current_scope) do
    Games.list_games(current_scope)
  end
end
