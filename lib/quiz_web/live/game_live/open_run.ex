defmodule QuizWeb.GameLive.OpenRun do
  @moduledoc """
  «Durchführung eröffnen» as used on the quiz page and in the question editor:
  the header button, the confirmation shown when some questions are still
  unfinished («Ohne diese eröffnen»), and the events behind them.

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
      class="btn btn-primary btn-sm"
    >
      <.icon name="hero-play" class="size-4" /> Durchführung eröffnen
    </button>
    """
  end

  @doc """
  Lists the unfinished questions after «Durchführung eröffnen» and offers to
  open without them — unless none would be left to play.
  """
  attr :game, :map, required: true
  attr :questions, :list, required: true, doc: "all of the game's questions"
  attr :incomplete, :list, required: true
  attr :class, :any, default: nil

  def confirm(assigns) do
    ~H"""
    <div
      :if={@incomplete != []}
      id="incomplete-confirm"
      class={["rounded-box border border-warning/40 bg-warning/10 p-5", @class]}
    >
      <h3 class="flex items-center gap-2 font-bold">
        <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
        {incomplete_title(length(@incomplete))}
      </h3>
      <ul class="mt-3 space-y-2 text-sm">
        <li :for={question <- @incomplete}>
          <.link
            navigate={~p"/games/#{@game}/questions/#{question}/edit"}
            class="font-medium hover:underline"
          >
            {question_label(question)}
          </.link>
          <span class="text-base-content/60">
            – es fehlt {Enum.join(Question.missing_requirements(question), ", ")}
          </span>
        </li>
      </ul>

      <%= if length(@incomplete) < length(@questions) do %>
        <p class="mt-4 text-sm text-base-content/70">
          Du kannst trotzdem eröffnen – diese Fragen werden dann in der Durchführung
          übersprungen. Beim nächsten Eröffnen sind sie wieder dabei, sobald sie fertig sind.
        </p>
        <div class="mt-4 flex flex-wrap gap-2">
          <button
            id="open-run-skipping"
            type="button"
            phx-click="open_run_skipping"
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-play" class="size-4" /> Ohne diese eröffnen
          </button>
          <button type="button" phx-click="dismiss_incomplete" class="btn btn-ghost btn-sm">
            Abbrechen
          </button>
        </div>
      <% else %>
        <p class="mt-4 text-sm text-base-content/70">
          Noch keine Frage ist spielbereit. Ergänze zuerst mindestens eine, dann kannst du
          eröffnen.
        </p>
        <button type="button" phx-click="dismiss_incomplete" class="btn btn-ghost btn-sm mt-3">
          Schliessen
        </button>
      <% end %>
    </div>
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
        {:noreply, put_flash(socket, :error, "Durchführung konnte nicht eröffnet werden.")}
    end
  end

  defp question_label(%{prompt: prompt, position: position}) when prompt in [nil, ""],
    do: "Frage #{position} (ohne Fragetext)"

  defp question_label(%{prompt: prompt}), do: prompt

  defp incomplete_title(1), do: "1 Frage ist noch nicht fertig"
  defp incomplete_title(n), do: "#{n} Fragen sind noch nicht fertig"
end
