defmodule QuizWeb.PlayLive.Play do
  @moduledoc """
  Participant runtime: waiting room, then the current question once the operator
  starts the quiz.

  Identity is held client-side: on enrollment a signed token is written to
  `localStorage`, and here the colocated `.RestoreParticipant` hook reads it back
  on (re)mount and rebinds the team. Because `localStorage` is unavailable during
  the dead render and the first connected render, we mount in a `:restoring`
  state and only resolve the participant from the hook's event — never redirect
  for a "missing" participant in `mount/3`.
  """
  use QuizWeb, :live_view

  alias Quiz.Play
  alias QuizWeb.QuestionLive.AnswerArea
  alias QuizWeb.LeaderboardComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="play-root"
      phx-hook=".RestoreParticipant"
      data-code={@join_code}
      class="min-h-screen bg-base-200"
    >
      <div
        :if={@restoring}
        class="min-h-screen flex flex-col items-center justify-center gap-3 text-base-content/60"
      >
        <span class="loading loading-spinner loading-lg"></span>
        <p class="text-sm">Verbinde …</p>
      </div>

      <div
        :if={!@restoring && @game.status == :open}
        class="min-h-screen flex flex-col items-center p-4 pt-10 sm:pt-16"
      >
        <div class="w-full max-w-sm text-center">
          <div class="text-6xl">⏳</div>
          <h1 class="mt-4 text-3xl font-extrabold text-primary">Warteraum</h1>
          <p class="mt-3 text-lg leading-snug text-base-content/55">
            Das Quiz startet, sobald die Quizmaster:in loslegt.
          </p>
          <div class="mt-6 flex justify-center">
            <span class="inline-flex items-center gap-2 rounded-full border border-base-300 bg-base-100 px-4 py-1.5 text-sm text-base-content/60 shadow-sm">
              <span class="size-2.5 translate-y-px rounded-full bg-success animate-pulse"></span>
              verbunden als <span class="font-semibold text-base-content">{@participant.name}</span>
            </span>
          </div>
        </div>
      </div>

      <div :if={!@restoring && @game.status == :running} class="flex flex-col items-center">
        <div class="w-full bg-primary px-6 py-4 flex items-center justify-between gap-3">
          <span class="text-sm font-bold uppercase tracking-[0.15em] text-secondary">
            Frage {@q_number}
          </span>
          <span class="shrink-0 max-w-[55%] truncate rounded-full border border-secondary/60 px-3 py-1 text-sm font-medium text-secondary">
            {@participant.name}
          </span>
        </div>

        <div :if={@question} class="w-full max-w-sm px-4 flex flex-col">
          <div class="py-6 border-b border-base-300">
            <p class="flex items-end gap-1 leading-none">
              <span class="font-display text-7xl sm:text-8xl font-extrabold tabular-nums text-secondary">
                {@q_number}
              </span>
              <span class="mb-2 text-xl font-medium text-base-content/40">/ {@q_total}</span>
            </p>
            <h1 class="mt-5 text-3xl font-extrabold leading-tight text-primary">
              {@question.prompt}
            </h1>
            <.rich_text :if={@question.description not in [nil, ""]} html={@question.description} />
            <.question_media question={@question} class="mt-4" />
          </div>

          <%!-- Reveal phase (per_question mode): the question is closed. Lock the
               form and point the room at the presenter screen, but still show the
               team their own submitted answer for reference during the discussion. --%>
          <div :if={@game.revealing} class="py-6">
            <div class="rounded-[2rem] bg-base-100 p-8 text-center shadow-sm">
              <div class="mx-auto grid size-20 place-items-center rounded-full bg-primary/10">
                <.icon name="hero-presentation-chart-bar" class="size-10 text-primary" />
              </div>
              <h2 class="mt-6 text-3xl font-extrabold text-primary">Auswertung</h2>
              <p class="mt-3 text-lg leading-snug text-base-content/55">
                Die Quizmaster:in bespricht die Lösung – schaut auf den Bildschirm.
              </p>

              <div
                :if={@answer}
                class="mt-6 rounded-2xl bg-base-100 ring-1 ring-base-300 p-5 text-left shadow-sm"
              >
                <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
                  Eure Antwort
                </p>
                <div class="mt-2">
                  <AnswerArea.answer_summary question={@question} answer={@answer} />
                </div>
              </div>
            </div>
          </div>

          <form
            :if={!@game.revealing && !@submitted}
            phx-submit="answer_submit"
            class="py-6 flex flex-col gap-4"
          >
            <fieldset class="m-0 min-w-0 border-0 p-0">
              <legend class="mb-2 text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
                Eure Antwort
              </legend>
              <AnswerArea.answer_area question={@question} />
            </fieldset>
            <button
              type="submit"
              class="mt-6 w-full h-14 rounded-field bg-primary text-secondary text-lg font-bold tracking-wide shadow-sm transition hover:brightness-110 active:scale-[0.99]"
            >
              Abschicken <span aria-hidden="true">→</span>
            </button>
          </form>

          <div :if={!@game.revealing && @submitted} class="py-6">
            <div class="rounded-[2rem] bg-base-100 p-8 text-center shadow-sm">
              <div class="mx-auto grid size-20 place-items-center rounded-full bg-warning">
                <.icon name="hero-check" class="size-10 text-primary" />
              </div>
              <h2 class="mt-6 text-3xl font-extrabold text-primary">Antwort abgeschickt!</h2>
              <p class="mt-3 text-lg leading-snug text-base-content/55">
                Quizmaster:in wertet aus und schaltet die nächste Frage frei.
              </p>

              <div class="mt-6 rounded-2xl bg-base-100 ring-1 ring-base-300 p-5 text-left shadow-sm">
                <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
                  Eure Antwort
                </p>
                <div class="mt-2">
                  <AnswerArea.answer_summary question={@question} answer={@answer} />
                </div>
              </div>

              <button
                type="button"
                phx-click="change_answer"
                class="mt-4 w-full h-14 rounded-field border border-base-300 text-lg font-semibold text-base-content/60 transition hover:bg-base-200"
              >
                Antwort ändern
              </button>
            </div>
          </div>
        </div>

        <div :if={!@question} class="py-8 text-center text-sm text-base-content/60">
          Keine Frage verfügbar.
        </div>
      </div>

      <div
        :if={!@restoring && @game.status in [:finished, :closed]}
        class="min-h-screen flex flex-col items-center p-4 pt-10 sm:pt-16 text-center"
      >
        <div class="text-6xl">🎉</div>
        <h1 class="mt-4 text-3xl font-extrabold text-primary">Quiz zu Ende</h1>

        <div :if={@game.grading_published} class="mt-8 w-full max-w-sm text-left">
          <p class="mb-3 text-center text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
            Rangliste
          </p>
          <LeaderboardComponent.standings rows={@leaderboard} highlight_id={@participant.id} />
        </div>

        <p :if={!@game.grading_published} class="mt-3 text-lg leading-snug text-base-content/55">
          Danke fürs Mitspielen, <span class="font-semibold text-base-content">{@participant.name}</span>! Die Rangliste
          folgt nach der Korrektur.
        </p>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".RestoreParticipant">
        export default {
          // On a websocket reconnect (e.g. the browser app was suspended and
          // resumed) the server LiveView remounts and waits for the token again,
          // but the DOM survives, so mounted() alone would leave it waiting
          // forever on the spinner.
          mounted() { this.restore(); },
          reconnected() { this.restore(); },
          restore() {
            const code = this.el.dataset.code;
            let token = null;
            try { token = window.localStorage.getItem("quiz:" + code); } catch (_e) {}
            if (token) {
              this.pushEvent("restore_participant", { token });
            } else {
              this.pushEvent("no_participant", {});
            }
          },
        };
      </script>
    </div>
    """
  end

  @impl true
  def mount(%{"join_code" => join_code}, _session, socket) do
    case Play.get_game_for_play(join_code) do
      {:ok, game} ->
        {:ok,
         socket
         |> assign(:page_title, game.title)
         |> assign(:join_code, game.join_code)
         |> assign(:game, game)
         |> assign(:participant, nil)
         |> assign(:question, nil)
         |> assign(:canonical_question, nil)
         |> assign(:q_number, 0)
         |> assign(:q_total, 0)
         |> assign(:answer, nil)
         |> assign(:submitted, false)
         |> assign(:leaderboard, [])
         |> assign(:restoring, true)}

      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: ~p"/join?code=#{String.upcase(join_code)}")}
    end
  end

  @impl true
  def handle_event("restore_participant", %{"token" => token}, socket) do
    case Play.restore_participant(socket.assigns.game, token) do
      {:ok, participant} ->
        if connected?(socket), do: Play.subscribe(socket.assigns.game)

        {:noreply,
         socket
         |> assign(:participant, participant)
         |> assign(:restoring, false)
         |> load_question()
         |> maybe_load_leaderboard()}

      {:error, _} ->
        {:noreply, to_join(socket)}
    end
  end

  def handle_event("no_participant", _params, socket) do
    {:noreply, to_join(socket)}
  end

  def handle_event("answer_submit", params, socket) do
    %{game: game, participant: participant, canonical_question: question} = socket.assigns

    case Play.submit_answer(game, participant, question, params) do
      {:ok, answer} ->
        {:noreply,
         socket
         |> assign(:answer, answer.payload["value"])
         |> assign(:submitted, true)}

      {:error, :not_accepting_answers} ->
        {:noreply, put_flash(socket, :error, "Diese Frage ist bereits geschlossen.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Antwort konnte nicht gespeichert werden.")}
    end
  end

  def handle_event("change_answer", _params, socket) do
    {:noreply, assign(socket, :submitted, false)}
  end

  @impl true
  def handle_info({:status_changed, game}, socket) do
    {:noreply, socket |> assign(:game, game) |> load_question()}
  end

  def handle_info({:participant_joined, _participant}, socket) do
    {:noreply, socket}
  end

  def handle_info({:answer_submitted, _position}, socket) do
    {:noreply, socket}
  end

  # The standings arrive precomputed in the broadcast (see
  # `Play.publish_grading/2`) — render them as-is rather than having all
  # participant screens hit the database for the same rows at the same instant.
  # `maybe_load_leaderboard/1` below stays as the naturally staggered fallback
  # for participants who (re)connect after publication.
  def handle_info({:grading_published, game, leaderboard}, socket) do
    {:noreply, socket |> assign(:game, game) |> assign(:leaderboard, leaderboard)}
  end

  # Ignore any other run broadcasts we don't act on, so a new message type can
  # never crash all participant screens at once mid-quiz (same guard as the
  # host/presenter view).
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp maybe_load_leaderboard(socket) do
    if socket.assigns.game.grading_published do
      assign(socket, :leaderboard, Play.leaderboard(socket.assigns.game))
    else
      socket
    end
  end

  defp load_question(socket) do
    # The canonical question (stored authoring order) is what we grade against.
    # `prepare_question/1` derives a display copy — for `:sequence` it shuffles
    # the items so the answer order isn't given away — which must never be used
    # for scoring, or the shuffle would become the "correct" order.
    canonical = Play.current_question(socket.assigns.game)
    question = canonical && AnswerArea.prepare_question(canonical)

    {number, total} = Play.question_numbering(socket.assigns.game)

    existing = canonical && Play.get_answer(socket.assigns.participant, canonical)

    socket
    |> assign(:question, question)
    |> assign(:canonical_question, canonical)
    |> assign(:q_number, number)
    |> assign(:q_total, total)
    |> assign(:answer, existing && existing.payload["value"])
    |> assign(:submitted, existing != nil)
  end

  defp to_join(socket) do
    push_navigate(socket, to: ~p"/join?code=#{socket.assigns.join_code}")
  end
end
