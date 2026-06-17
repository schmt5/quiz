defmodule QuizWeb.CorrectionLive.Index do
  @moduledoc """
  Corrector overview: every question in the run with its answer count and
  correction status. The corrector jumps into a question to grade its answers
  in bulk, and publishes the grading when done — revealing the leaderboard.
  Runs in parallel to the moderator; teams never see this.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:page_header>
        <div class="mx-auto max-w-7xl">
          <div class="breadcrumbs text-xs">
            <ul>
              <li>
                <.link navigate={~p"/"} aria-label="Home">
                  <.icon name="hero-home" class="size-4" />
                </.link>
              </li>
              <li><.link navigate={~p"/games"}>Quizze</.link></li>
              <li><.link navigate={~p"/games/#{@game}"}>{@game.title}</.link></li>
              <li>Korrektur</li>
            </ul>
          </div>
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-2">
              <div class="tooltip tooltip-right" data-tip="Zurück zum Quiz">
                <.link
                  navigate={~p"/games/#{@game}"}
                  class="btn btn-ghost btn-sm btn-square"
                  aria-label="Zurück zum Quiz"
                >
                  <.icon name="hero-arrow-left" class="size-4" />
                </.link>
              </div>
              <h1 class="text-2xl font-bold">Korrektur</h1>
              <span
                :if={@game.grading_published}
                class="badge badge-soft badge-primary shrink-0 font-semibold border! border-primary!"
              >
                veröffentlicht
              </span>
            </div>
            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="publish"
                data-confirm={
                  (@done_count < @gradable_count &&
                     "Es sind noch nicht alle Fragen geprüft. Trotzdem veröffentlichen?") || nil
                }
                disabled={@game.grading_published}
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-check-circle" class="size-4" /> Veröffentlichen
              </button>
              <.link navigate={~p"/games/#{@game}/leaderboard"} class="btn btn-ghost btn-sm">
                <.icon name="hero-trophy" class="size-4" /> Rangliste
              </.link>
            </div>
          </div>
        </div>
      </:page_header>

      <div class="mx-auto max-w-3xl py-6 space-y-4">
        <p :if={!@game.grading_published} class="text-sm text-base-content/60">
          {@done_count} von {@gradable_count} Fragen geprüft.
        </p>

        <ol class="space-y-2 list-none p-0">
          <li :for={{row, idx} <- Enum.with_index(@overview, 1)}>
            <.link
              :if={row.gradable}
              navigate={~p"/games/#{@game}/correction/#{row.question.position}"}
              class="flex items-center gap-3 rounded-box bg-base-100 ring-1 ring-base-300 px-4 py-3 hover:ring-primary transition"
            >
              {render_row(assign(assigns, row: row, idx: idx))}
              <.icon name="hero-chevron-right" class="size-5 text-base-content/30" />
            </.link>

            <div
              :if={!row.gradable}
              class="flex items-center gap-3 rounded-box bg-base-200/60 px-4 py-3"
            >
              {render_row(assign(assigns, row: row, idx: idx))}
              <span class="badge badge-ghost">auto</span>
            </div>
          </li>
        </ol>
      </div>
    </Layouts.app>
    """
  end

  defp render_row(assigns) do
    ~H"""
    <span class="font-display text-lg font-extrabold tabular-nums text-base-content/40 w-6 text-right">
      {@idx}
    </span>
    <div class="flex-1 min-w-0">
      <p class="font-medium truncate">{@row.question.prompt}</p>
      <p class="text-xs text-base-content/55">
        {type_label(@row.question.type)} · {@row.answer_count} Antworten
      </p>
    </div>
    <span
      :if={@row.gradable && @row.done}
      class="badge badge-soft badge-primary font-semibold border! border-primary!"
    >
      korrigiert
    </span>
    <span :if={@row.gradable && !@row.done} class="badge badge-warning">zu prüfen</span>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)
    if connected?(socket), do: Play.subscribe(game)

    {:ok,
     socket
     |> assign(:page_title, "Korrektur: #{game.title}")
     |> assign(:game, game)
     |> assign_overview()}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    case Play.publish_grading(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} ->
        {:noreply, socket |> assign(:game, game) |> put_flash(:info, "Wertung veröffentlicht.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Konnte nicht veröffentlicht werden.")}
    end
  end

  @impl true
  def handle_info({:answer_submitted, _position}, socket) do
    {:noreply, assign_overview(socket)}
  end

  def handle_info({:grading_published, game}, socket) do
    {:noreply, assign(socket, :game, game)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_overview(socket) do
    overview = Play.correction_overview(socket.assigns.game)
    gradable = Enum.filter(overview, & &1.gradable)

    socket
    |> assign(:overview, overview)
    |> assign(:gradable_count, length(gradable))
    |> assign(:done_count, Enum.count(gradable, & &1.done))
  end

  defp type_label(:text_input), do: "Texteingabe"
  defp type_label(:single_choice), do: "Auswahl"
  defp type_label(:sequence), do: "Reihenfolge"
  defp type_label(:matching), do: "Zuordnung"
  defp type_label(:pin_on_image), do: "Bildmarkierung"
  defp type_label(_), do: "Frage"
end
