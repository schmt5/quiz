defmodule QuizWeb.GameLive.OpenRun do
  @moduledoc """
  «Quiz starten» (opening the run) as used on the quiz page and in the question editor:
  the header button, the confirmation shown when some questions are still
  unfinished («Ohne diese starten»), and the events behind them.

  A LiveView using it calls `assign_defaults/1` in `mount/3`, renders
  `run_button/1` and `confirm/1`, and hands the events in `events/0` to
  `handle_event/3`.
  """
  use QuizWeb, :html

  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3]

  alias Quiz.Games.Question

  @events ~w(open_run open_run_skipping dismiss_incomplete)

  @doc "The events `handle_event/3` handles."
  def events, do: @events

  def assign_defaults(socket), do: assign(socket, :incomplete_questions, [])

  @doc """
  The primary header action: open the run, or go to it when it is already open
  or running. Renders nothing for a quiz without questions or after the run.
  """
  attr :game, :map, required: true
  attr :has_questions, :boolean, required: true

  def run_button(assigns) do
    ~H"""
    <.link
      :if={@has_questions and @game.status in [:open, :running]}
      id="go-to-run"
      navigate={~p"/games/#{@game}/run"}
      class="btn btn-primary btn-sm"
    >
      <.icon name="hero-arrow-right" class="size-4" /> Zur Durchführung
    </.link>
    <button
      :if={@has_questions and @game.status in [:draft, :closed]}
      id="open-run"
      type="button"
      phx-click="open_run"
      class="btn btn-primary shadow-md shadow-primary/25 transition hover:-translate-y-px hover:shadow-lg hover:shadow-primary/30"
    >
      <.icon name="hero-play-solid" class="size-5" /> Quiz starten
    </button>
    """
  end

  @doc """
  Lists the unfinished questions after «Quiz starten» and offers to start
  without them — unless none would be left to play. A modal dialog, so it is
  seen wherever the page is scrolled to; closing it (also with Esc or the
  backdrop) clears `:incomplete_questions`, so the next click opens it again.
  """
  attr :game, :map, required: true
  attr :questions, :list, required: true, doc: "all of the game's questions"
  attr :incomplete, :list, required: true

  def confirm(assigns) do
    ~H"""
    <dialog
      :if={@incomplete != []}
      id="incomplete-confirm"
      class="modal"
      phx-hook=".IncompleteDialog"
      aria-labelledby="incomplete-confirm-title"
    >
      <div class="modal-box max-w-lg">
        <div class="flex items-start gap-4">
          <span class="flex size-11 shrink-0 items-center justify-center rounded-full bg-warning/15 text-warning">
            <.icon name="hero-exclamation-triangle" class="size-5" />
          </span>
          <div class="min-w-0">
            <h2 id="incomplete-confirm-title" class="text-lg font-bold">
              {incomplete_title(length(@incomplete))}
            </h2>
            <ul class="mt-3 space-y-2 text-base">
              <li :for={question <- @incomplete}>
                <.link
                  navigate={~p"/games/#{@game}/questions/#{question}/edit"}
                  class="font-semibold text-primary hover:underline"
                >
                  {question_label(question)}
                </.link>
                <span class="text-base-content/80">
                  – es fehlt {Enum.join(Question.missing_requirements(question), ", ")}
                </span>
              </li>
            </ul>
            <p class="mt-4 text-base text-base-content/80">
              {if length(@incomplete) < length(@questions),
                do:
                  "Du kannst trotzdem starten – diese Fragen werden dann übersprungen. Beim nächsten Start sind sie wieder dabei, sobald sie fertig sind.",
                else:
                  "Noch keine Frage ist spielbereit. Ergänze zuerst mindestens eine, dann kannst du starten."}
            </p>
          </div>
        </div>
        <div class="modal-action">
          <button
            id="incomplete-confirm-cancel"
            type="button"
            phx-click="dismiss_incomplete"
            class="btn btn-ghost"
          >
            {if length(@incomplete) < length(@questions), do: "Abbrechen", else: "Schliessen"}
          </button>
          <button
            :if={length(@incomplete) < length(@questions)}
            id="open-run-skipping"
            type="button"
            phx-click="open_run_skipping"
            class="btn btn-primary"
          >
            <.icon name="hero-play" class="size-4" /> Ohne diese starten
          </button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop"><button>schliessen</button></form>
    </dialog>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".IncompleteDialog">
      export default {
        mounted() {
          // Esc and the backdrop close the dialog in the browser only: tell the
          // server, or a second «Quiz starten» would change nothing to show.
          this.el.addEventListener("close", () => this.pushEvent("dismiss_incomplete", {}))
          this.el.showModal()
        }
      }
    </script>
    """
  end

  @doc "Handles the events in `events/0` for a LiveView with a `:game` assign."
  def handle_event("open_run", _params, socket), do: open(socket, [])

  def handle_event("open_run_skipping", _params, socket),
    do: open(socket, skip_incomplete: true)

  def handle_event("dismiss_incomplete", _params, socket),
    do: {:noreply, assign(socket, :incomplete_questions, [])}

  defp open(socket, opts) do
    case Quiz.Play.open_run(socket.assigns.current_scope, socket.assigns.game, opts) do
      {:ok, game} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game}/run")}

      {:error, {:incomplete_questions, questions}} ->
        {:noreply, assign(socket, :incomplete_questions, questions)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Das Quiz konnte nicht gestartet werden.")}
    end
  end

  defp question_label(%{prompt: prompt, position: position}) when prompt in [nil, ""],
    do: "Frage #{position} (ohne Fragetext)"

  defp question_label(%{prompt: prompt}), do: prompt

  defp incomplete_title(1), do: "1 Frage ist noch nicht fertig"
  defp incomplete_title(n), do: "#{n} Fragen sind noch nicht fertig"
end
