defmodule QuizWeb.RunLive.Stage do
  @moduledoc """
  The "stage" of a run: what the room sees on the projector.

  Shared by the operator's control views (`QuizWeb.RunLive.Host`,
  `QuizWeb.RunLive.Review`), which wrap it with their controls, and by the
  guest-facing presentation window (`QuizWeb.RunLive.Screen`), which renders it
  without any. `controls` switches the operator-only bits (remove-team buttons,
  statistics toggle) on and off; everything else is identical on both screens.
  """
  use QuizWeb, :html

  alias Quiz.Games.Question
  alias QuizWeb.QuestionLive.{SolutionArea, StatsArea}

  @doc """
  The lobby: brand, live team count and roster on the left, how to join (QR
  code, URL, PIN tiles) on the right. Operator actions go into `:actions`.
  """
  attr :game, :map, required: true
  attr :participants, :list, required: true
  attr :qr_svg, :string, required: true
  attr :controls, :boolean, default: false
  slot :actions

  def lobby(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row lg:h-screen lg:overflow-hidden">
      <%!-- Left: brand, live team count, connected teams, start action --%>
      <div class="lg:w-3/5 flex flex-col gap-8 bg-primary text-base-100 p-8 sm:p-12 lg:overflow-y-auto">
        <div class="flex items-start justify-between gap-6">
          <div>
            <p class="font-display text-5xl sm:text-6xl font-extrabold leading-none">
              along<span class="text-secondary">events</span>
            </p>
            <p class="mt-2 text-base-100/55 truncate max-w-xs sm:max-w-sm">{@game.title}</p>
          </div>
          <div class="text-right shrink-0">
            <p class="font-display text-5xl sm:text-6xl font-extrabold leading-none text-secondary tabular-nums">
              {length(@participants)}
            </p>
            <p class="mt-1 text-xs font-bold uppercase tracking-[0.18em] text-base-100/55">
              Teams bereit
            </p>
            <p
              :if={@game.enrollment_locked}
              class="mt-1 text-xs font-bold uppercase tracking-[0.18em] text-warning"
            >
              Anmeldung gesperrt
            </p>
          </div>
        </div>

        <div class="flex-1 min-h-0 flex flex-col gap-4">
          <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-100/55">
            Verbundene Teams
          </p>

          <p :if={@participants == []} class="text-base-100/55">
            Warte auf die ersten Teams …
          </p>

          <ul
            id="participants"
            class="grid grid-cols-1 sm:grid-cols-2 gap-3 list-none lg:overflow-y-auto"
          >
            <li
              :for={participant <- @participants}
              id={"participant-#{participant.id}"}
              class="flex items-center gap-3 rounded-box bg-white/10 px-4 py-3"
            >
              <span class="size-2.5 shrink-0 rounded-full bg-success"></span>
              <span class="font-medium truncate">{participant.name}</span>
              <button
                :if={@controls}
                type="button"
                phx-click="remove_participant"
                phx-value-id={participant.id}
                data-confirm={"Team «#{participant.name}» wirklich entfernen?"}
                title="Team entfernen"
                aria-label={"Team #{participant.name} entfernen"}
                class="ml-auto btn btn-ghost btn-xs btn-circle text-base-100/50 hover:text-base-100"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </li>
          </ul>
        </div>

        <div :if={@actions != []} class="flex flex-wrap items-center gap-3">
          {render_slot(@actions)}
        </div>
      </div>

      <%!-- Right: how to join — QR, alternative URL, per-character code tiles --%>
      <aside class="lg:w-2/5 flex flex-col items-center justify-center gap-8 bg-base-100 p-8 sm:p-12">
        <p class="text-sm font-bold uppercase tracking-[0.22em] text-primary">
          Jetzt beitreten
        </p>

        <div class="bg-white rounded-3xl shadow-sm ring-1 ring-base-300 p-6">
          <div class="size-72 sm:size-80 xl:size-96">{raw(@qr_svg)}</div>
        </div>

        <div class="flex w-full max-w-xs items-center gap-3 text-base-content/45">
          <span class="h-px flex-1 bg-base-300"></span>
          <span class="text-xs font-bold uppercase tracking-[0.2em]">oder</span>
          <span class="h-px flex-1 bg-base-300"></span>
        </div>

        <div class="text-center space-y-4">
          <p class="text-base-content/60">
            Gehe auf <span class="font-bold text-primary">{join_host()}</span> · PIN eingeben
          </p>
          <div class="flex justify-center gap-2">
            <span
              :for={char <- String.graphemes(@game.join_code)}
              class="grid size-12 sm:size-14 place-items-center rounded-box bg-base-200 ring-1 ring-base-300 font-display text-2xl sm:text-3xl font-extrabold text-primary"
            >
              {char}
            </span>
          </div>
        </div>
      </aside>
    </div>
    """
  end

  @doc """
  A question on stage. While answers are collected it shows the live answered
  count (when `answered_count` is given); while `revealing` it shows the
  sample solution, its explanation and — if the game opts in — the statistics
  panel, opened and closed by `show_stats`.
  """
  attr :question, Question, required: true
  attr :label, :string, default: nil
  attr :revealing, :boolean, default: false
  attr :answered_count, :integer, default: nil
  attr :participant_count, :integer, default: 0
  attr :show_statistics, :boolean, default: false
  attr :show_stats, :boolean, default: false
  attr :stats, :map, default: nil
  attr :controls, :boolean, default: false

  def question(assigns) do
    ~H"""
    <div class="space-y-6">
      <p :if={@label} class="text-sm font-bold uppercase tracking-[0.18em] text-base-content/45">
        {@label}
      </p>
      <h2 class="text-4xl sm:text-5xl font-extrabold leading-tight text-primary">
        {@question.prompt}
      </h2>
      <.rich_text :if={@question.description not in [nil, ""]} html={@question.description} />
      <.question_media question={@question} zoomable={@controls} />

      <%!-- Collecting answers: live answered count. --%>
      <div
        :if={!@revealing && @answered_count}
        id="answered-count"
        class="flex items-center gap-2 text-lg text-base-content/60"
      >
        <.icon name="hero-user-group" class="size-5" />
        <span>
          {@answered_count} / {@participant_count} Teams haben geantwortet
        </span>
      </div>

      <%!-- Revealing: sample solution, plus the optional statistics panel. It
           stays in the DOM and animates open via a grid-rows 0fr->1fr collapse,
           so the reveal eases instead of popping (respects reduced-motion). --%>
      <div :if={@revealing} class="space-y-6">
        <SolutionArea.solution_area question={@question} />
        <SolutionArea.solution_explanation question={@question} />

        <div :if={@show_statistics} class="pt-2">
          <button
            :if={@controls && !@show_stats}
            id="show-stats"
            type="button"
            phx-click="toggle_stats"
            class="btn btn-soft"
          >
            <.icon name="hero-chart-bar" class="size-5" /> Statistik einblenden
          </button>

          <div
            id="stats-panel"
            class={[
              "grid transition-[grid-template-rows] duration-300 ease-out motion-reduce:transition-none",
              (@show_stats && "grid-rows-[1fr]") || "grid-rows-[0fr]"
            ]}
          >
            <div class="overflow-hidden">
              <div class={[
                "space-y-3 transition-opacity duration-300 ease-out motion-reduce:transition-none",
                (@show_stats && "opacity-100") || "opacity-0"
              ]}>
                <div class="flex items-center justify-between">
                  <h3 class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
                    Statistik
                  </h3>
                  <button
                    :if={@controls}
                    type="button"
                    phx-click="toggle_stats"
                    class="btn btn-ghost btn-sm"
                  >
                    <.icon name="hero-chevron-up" class="size-4" /> Ausblenden
                  </button>
                </div>
                <StatsArea.stats_area :if={@stats} stats={@stats} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc "The closing screen once the last question is done."
  attr :game, :map, required: true
  attr :has_questions, :boolean, required: true

  def finished(assigns) do
    ~H"""
    <div id="finished-stage" class="text-center space-y-4">
      <.icon name="hero-flag" class="size-16 text-primary" />
      <p class="text-3xl font-bold">Quiz beendet.</p>
      <p :if={@has_questions} class="text-lg text-base-content/60">
        Geh die Lösungen mit allen durch – danach geht's zur Rangliste.
      </p>
    </div>
    """
  end

  @doc "Small QR code plus PIN so late teams can still join mid-quiz."
  attr :game, :map, required: true
  attr :qr_svg, :string, required: true

  def join_badge(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="size-20 shrink-0 bg-white rounded-xl p-1.5 ring-1 ring-base-300">
        {raw(@qr_svg)}
      </div>
      <div class="min-w-0">
        <p class="text-xs font-bold uppercase tracking-wider text-base-content/45">
          Mitmachen
        </p>
        <div class="flex gap-1 mt-1">
          <span
            :for={char <- String.graphemes(@game.join_code)}
            class="font-display font-extrabold text-lg text-primary"
          >
            {char}
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc "The \"PubQuiz\" wordmark heading the run screens."
  attr :link, :boolean, default: true

  def brand(assigns) do
    ~H"""
    <.link
      :if={@link}
      navigate={~p"/"}
      class="inline-flex items-baseline text-2xl font-extrabold tracking-tight shrink-0"
    >
      <span class="text-primary">Pub</span>
      <span class="bg-primary text-secondary rounded-xl px-2 py-0.5">Quiz</span>
    </.link>
    <span
      :if={!@link}
      class="inline-flex items-baseline text-2xl font-extrabold tracking-tight shrink-0"
    >
      <span class="text-primary">Pub</span>
      <span class="bg-primary text-secondary rounded-xl px-2 py-0.5">Quiz</span>
    </span>
    """
  end

  @doc """
  Keyboard control for the operator's run views: → / Space / PageDown push a
  `"shortcut"` event with `action: "next"`, ← / PageUp `"prev"` and S
  `"stats"`; the view decides what that means in its current state. These are
  also the keys presenter clickers send. ? opens the shortcut overview.

  Keys are ignored while typing in a field, with a modifier held, on key
  repeat and while a dialog is open; Space on a focused button keeps its
  native click.
  """
  def keyboard(assigns) do
    ~H"""
    <div id="run-keys" phx-hook=".RunKeys" class="hidden"></div>

    <dialog id="shortcuts_modal" class="modal">
      <div class="modal-box max-w-md">
        <form method="dialog">
          <button
            class="btn btn-sm btn-circle btn-ghost absolute right-4 top-4"
            aria-label="Schliessen"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </form>
        <h2 class="text-xl font-extrabold text-primary">Tastenkürzel</h2>
        <dl class="mt-6 grid grid-cols-[auto_1fr] items-center gap-x-6 gap-y-3 text-sm">
          <dt class="flex flex-wrap gap-1">
            <kbd class="kbd kbd-sm">→</kbd>
            <kbd class="kbd kbd-sm">Leertaste</kbd>
            <kbd class="kbd kbd-sm">Bild ↓</kbd>
          </dt>
          <dd>Nächster Schritt: auswerten, nächste Frage oder Lösung</dd>
          <dt class="flex flex-wrap gap-1">
            <kbd class="kbd kbd-sm">←</kbd>
            <kbd class="kbd kbd-sm">Bild ↑</kbd>
          </dt>
          <dd>Einen Schritt zurück</dd>
          <dt><kbd class="kbd kbd-sm">S</kbd></dt>
          <dd>Statistik ein- und ausblenden</dd>
          <dt><kbd class="kbd kbd-sm">?</kbd></dt>
          <dd>Diese Übersicht</dd>
        </dl>
        <p class="mt-6 text-sm text-base-content/60">
          Das Quiz wird nie per Taste beendet, sondern nur über den Button «Quiz beenden».
        </p>
      </div>
      <form method="dialog" class="modal-backdrop"><button>schliessen</button></form>
    </dialog>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".RunKeys">
      export default {
        mounted() {
          const ACTIONS = {
            ArrowRight: "next", PageDown: "next", " ": "next",
            ArrowLeft: "prev", PageUp: "prev",
            s: "stats", S: "stats",
          };

          this.onKey = (e) => {
            if (e.defaultPrevented || e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
            if (e.target.closest("input, textarea, select, [contenteditable]")) return;
            if (document.querySelector("dialog[open]")) return;
            // Space on a focused button already clicks it; don't fire twice.
            if (e.key === " " && e.target.closest("button, a, summary")) return;

            if (e.key === "?") {
              e.preventDefault();
              document.getElementById("shortcuts_modal")?.showModal();
              return;
            }

            const action = ACTIONS[e.key];
            if (!action) return;
            e.preventDefault();
            this.pushEvent("shortcut", { action });
          };

          window.addEventListener("keydown", this.onKey);
        },
        destroyed() {
          window.removeEventListener("keydown", this.onKey);
        },
      };
    </script>
    """
  end

  @doc "Header button opening the shortcut overview of `keyboard/1`."
  def shortcuts_button(assigns) do
    ~H"""
    <button
      id="open-shortcuts"
      type="button"
      onclick="shortcuts_modal.showModal()"
      title="Tastenkürzel (?)"
      aria-label="Tastenkürzel anzeigen"
      class="btn btn-ghost btn-circle"
    >
      <.icon name="hero-command-line" class="size-6" />
    </button>
    """
  end

  @doc "SVG QR code linking to the enrollment page for this game's join code."
  def qr_svg(game) do
    (QuizWeb.Endpoint.url() <> ~p"/join?code=#{game.join_code}")
    |> EQRCode.encode()
    |> EQRCode.svg(viewbox: true, class: "w-full h-full", color: "#00555a")
  end

  # The bare host (no scheme) participants type into their browser, derived from
  # the configured endpoint URL — e.g. "wasdas.app" or "localhost:4000".
  defp join_host do
    QuizWeb.Endpoint.url()
    |> URI.parse()
    |> then(&[&1.host, &1.port])
    |> case do
      [host, port] when port in [nil, 80, 443] -> host
      [host, port] -> "#{host}:#{port}"
    end
  end
end
