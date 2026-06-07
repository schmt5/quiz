defmodule QuizWeb.CorrectionLive.Question do
  @moduledoc """
  Bulk correction of one question: every team's answer bucketed into groups of
  identical answers, each judged once (richtig / halb / falsch) and applied to
  the whole group. Keyboard-fast: J/K/L judge the focused group, Tab moves to the
  next, Enter finalises ("Fertig").
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play}

  @grades %{"full" => :full, "half" => :half, "zero" => :zero}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:page_header>
        <div class="mx-auto max-w-2xl">
          <div class="breadcrumbs text-xs">
            <ul>
              <li>
                <.link navigate={~p"/"} aria-label="Home">
                  <.icon name="hero-home" class="size-4" />
                </.link>
              </li>
              <li><.link navigate={~p"/games"}>Quizze</.link></li>
              <li><.link navigate={~p"/games/#{@game}"}>{@game.title}</.link></li>
              <li><.link navigate={~p"/games/#{@game}/correction"}>Korrektur</.link></li>
              <li>Frage {@number} / {@total}</li>
            </ul>
          </div>
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-2 min-w-0">
              <div class="tooltip tooltip-right" data-tip="Zurück zur Übersicht">
                <.link
                  navigate={~p"/games/#{@game}/correction"}
                  class="btn btn-ghost btn-sm btn-square"
                  aria-label="Zurück zur Übersicht"
                >
                  <.icon name="hero-arrow-left" class="size-4" />
                </.link>
              </div>
              <h1 class="text-2xl font-bold truncate">{@question.prompt}</h1>
            </div>
            <button type="button" phx-click="done" class="btn btn-primary btn-sm shrink-0">
              <.icon name="hero-check" class="size-4" /> Fertig
            </button>
          </div>
        </div>
      </:page_header>

      <div id="correction" phx-hook=".Keyboard" class="max-w-2xl mx-auto py-6 space-y-6">
        <div class="flex flex-col gap-1">
          <p class="text-xs text-base-content/50">
            <kbd class="kbd kbd-sm">J</kbd>
            richtig · <kbd class="kbd kbd-sm">K</kbd>
            halb · <kbd class="kbd kbd-sm">L</kbd>
            falsch · <kbd class="kbd kbd-sm">Tab</kbd>
            nächste · <kbd class="kbd kbd-sm">⏎</kbd>
            fertig
          </p>
          <p :if={@solution} class="text-sm text-base-content/60">
            Lösung: <span class="font-medium text-base-content">{@solution}</span>
          </p>
        </div>

        <p :if={@done} class="text-sm text-success font-medium">
          <.icon name="hero-check-circle" class="size-5" /> Als geprüft markiert
        </p>

        <p :if={@groups == []} class="rounded-box bg-base-200 p-6 text-center text-base-content/60">
          Noch keine Antworten.
        </p>

        <ul class="space-y-3 list-none p-0">
          <li
            :for={{group, idx} <- Enum.with_index(@groups)}
            tabindex="0"
            data-group-index={idx}
            class={[
              "group rounded-box ring-1 px-4 py-3 outline-none transition",
              "focus:ring-2 focus:ring-primary",
              grade_ring(group.grade)
            ]}
          >
            <div class="flex items-center justify-between gap-3">
              <div class="min-w-0">
                <p class={[
                  "text-lg font-semibold truncate",
                  group.blank && "italic text-base-content/40"
                ]}>
                  {(group.blank && "— keine Antwort —") || group.label}
                </p>
                <p class="text-xs text-base-content/55 truncate">
                  {group.count}× · {Enum.join(group.participants, ", ")}
                </p>
              </div>

              <div class="flex shrink-0 gap-1">
                <button
                  :for={{grade, label, cls} <- judge_buttons()}
                  type="button"
                  phx-click="grade"
                  phx-value-index={idx}
                  phx-value-grade={grade}
                  class={[
                    "btn btn-sm",
                    (to_string(group.grade) == grade && cls) || "btn-ghost"
                  ]}
                >
                  {label}
                </button>
              </div>
            </div>
          </li>
        </ul>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Keyboard">
        export default {
          mounted() {
            const first = this.el.querySelector("[data-group-index]");
            if (first) first.focus();

            this.onKey = (e) => {
              if (e.target.matches("input, textarea")) return;
              const key = e.key.toLowerCase();

              if (key === "enter") {
                e.preventDefault();
                this.pushEvent("done", {});
                return;
              }

              const grade = { j: "full", k: "half", l: "zero" }[key];
              if (!grade) return;

              const row = document.activeElement?.closest("[data-group-index]");
              if (!row) return;
              e.preventDefault();
              this.pushEvent("grade", { index: row.dataset.groupIndex, grade });
            };
            window.addEventListener("keydown", this.onKey);
          },
          destroyed() {
            window.removeEventListener("keydown", this.onKey);
          },
        };
      </script>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id, "position" => position}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)
    position = String.to_integer(position)
    question = Play.get_question(game, position)

    cond do
      is_nil(question) or question.type != :text_input ->
        {:ok, push_navigate(socket, to: ~p"/games/#{game}/correction")}

      true ->
        if connected?(socket), do: Play.subscribe(game)
        {number, total} = Play.question_numbering(%{game | current_position: position})

        {:ok,
         socket
         |> assign(:page_title, "Korrektur: Frage #{number}")
         |> assign(:game, game)
         |> assign(:question, question)
         |> assign(:number, number)
         |> assign(:total, total)
         |> assign(:solution, solution_hint(question))
         |> assign(:done, Play.correction_done?(question))
         |> assign_groups()}
    end
  end

  @impl true
  def handle_event("grade", %{"index" => index, "grade" => grade}, socket) do
    grade = Map.fetch!(@grades, grade)
    group = Enum.at(socket.assigns.groups, String.to_integer(index))

    if group do
      {:ok, _} = Play.grade_group(group.answer_ids, grade)

      groups =
        List.replace_at(socket.assigns.groups, String.to_integer(index), %{group | grade: grade})

      {:noreply, assign(socket, :groups, groups)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("done", _params, socket) do
    {:ok, _} = Play.mark_question_done(socket.assigns.question)

    case next_position(socket.assigns.game, socket.assigns.question.position) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:info, "Frage geprüft.")
         |> push_navigate(to: ~p"/games/#{socket.assigns.game}/correction")}

      position ->
        {:noreply,
         push_navigate(socket, to: ~p"/games/#{socket.assigns.game}/correction/#{position}")}
    end
  end

  @impl true
  def handle_info({:answer_submitted, position}, socket) do
    if position == socket.assigns.question.position do
      {:noreply, assign_groups(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_groups(socket) do
    pairs = Play.list_answers_for_question(socket.assigns.question)
    assign(socket, :groups, Play.group_answers(socket.assigns.question, pairs))
  end

  # The next gradable question after `position`, or nil.
  defp next_position(game, position) do
    game
    |> Play.correction_overview()
    |> Enum.filter(&(&1.gradable and &1.question.position > position))
    |> List.first()
    |> case do
      nil -> nil
      row -> row.question.position
    end
  end

  defp solution_hint(%{type: :text_input, data: %{solutions: solutions}}) do
    case Enum.map(solutions, & &1.text) do
      [] -> nil
      texts -> Enum.join(texts, " / ")
    end
  end

  defp solution_hint(_question), do: nil

  defp judge_buttons do
    [
      {"full", "richtig", "btn-success"},
      {"half", "halb", "btn-warning"},
      {"zero", "falsch", "btn-error"}
    ]
  end

  defp grade_ring(:full), do: "bg-success/5 ring-success/40"
  defp grade_ring(:half), do: "bg-warning/5 ring-warning/40"
  defp grade_ring(:zero), do: "bg-error/5 ring-error/40"
end
