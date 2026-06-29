defmodule QuizWeb.RunLive.Host do
  @moduledoc """
  Operator "landing page" for a running quiz (the lobby). Shows the join code,
  a QR code linking to the enrollment page, and the live list of enrolled teams.
  From here the operator starts the quiz.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play, Stats}
  alias QuizWeb.QuestionLive.{SolutionArea, StatsArea}

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Lobby (:open): two-pane presenter view matching the "wasdas?" mockup. --%>
    <div :if={@game.status == :open} class="flex flex-col lg:flex-row lg:h-screen lg:overflow-hidden">
      <%!-- Left: brand, live team count, connected teams, start action --%>
      <div class="lg:w-3/5 flex flex-col gap-8 bg-primary text-base-100 p-8 sm:p-12 lg:overflow-y-auto">
        <div class="flex items-start justify-between gap-6">
          <div>
            <p class="font-display text-5xl sm:text-6xl font-extrabold leading-none">
              was<span class="text-secondary">das?</span>
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
            </li>
          </ul>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <button
            type="button"
            phx-click="start"
            disabled={@participants == []}
            class="btn btn-secondary btn-lg"
          >
            <.icon name="hero-play" /> Quiz starten
          </button>
          <.link navigate={~p"/games/#{@game}"} class="btn btn-ghost btn-sm text-base-100/70">
            <.icon name="hero-arrow-left" class="size-4" /> Zurück zum Quiz
          </.link>
        </div>
      </div>

      <%!-- Right: how to join — QR, alternative URL, per-character code tiles --%>
      <aside class="lg:w-2/5 flex flex-col items-center justify-center gap-8 bg-base-100 p-8 sm:p-12">
        <p class="text-sm font-bold uppercase tracking-[0.22em] text-primary">
          Jetzt beitreten
        </p>

        <div class="bg-white rounded-3xl shadow-sm ring-1 ring-base-300 p-6">
          <div class="size-56 sm:size-64">{raw(@qr_svg)}</div>
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

    <%!-- Running / finished: unchanged single-column operator view. --%>
    <div
      :if={@game.status != :open}
      class="flex flex-col lg:flex-row lg:h-screen lg:overflow-hidden bg-base-100"
    >
      <%!-- Left 2/3: header (brand · title · primary action), then question / result --%>
      <div class="lg:w-2/3 flex flex-col min-h-0 lg:overflow-hidden">
        <div class="shrink-0 flex items-center justify-between gap-4 h-[84px] px-6 border-b border-base-300">
          <div class="flex items-center gap-4 min-w-0">
            <.link
              navigate={~p"/"}
              class="inline-flex items-baseline text-2xl font-extrabold tracking-tight shrink-0"
            >
              <span class="text-primary">Pub</span>
              <span class="bg-primary text-secondary rounded-xl px-2 py-0.5">Quiz</span>
            </.link>
            <h1 class="text-lg font-bold truncate">{@game.title}</h1>
          </div>

          <%!-- `per_question` mode inserts a reveal step: "Auswerten" closes the
               question and shows its solution/stats, then "Nächste Frage" advances.
               `end` mode advances straight away, exactly as before. --%>
          <button
            :if={
              @game.status == :running and @game.review_mode == :per_question and not @game.revealing
            }
            type="button"
            phx-click="reveal"
            class="btn btn-primary shrink-0"
          >
            <.icon name="hero-light-bulb" /> Auswerten
          </button>

          <button
            :if={
              @game.status == :running and
                not (@game.review_mode == :per_question and not @game.revealing)
            }
            type="button"
            phx-click="advance"
            class="btn btn-primary shrink-0"
          >
            <%= if @q_number >= @q_total and @q_total > 0 do %>
              <.icon name="hero-flag" /> Quiz beenden
            <% else %>
              Nächste Frage <.icon name="hero-arrow-right" />
            <% end %>
          </button>

          <div
            :if={@game.status in [:finished, :closed]}
            class="flex items-center gap-2 shrink-0"
          >
            <.link
              :if={@review_position && @game.review_mode == :end}
              navigate={~p"/games/#{@game}/review/#{@review_position}"}
              class="btn btn-primary"
            >
              <.icon name="hero-light-bulb" /> Lösungen besprechen
            </.link>
            <.link
              navigate={~p"/games/#{@game}/leaderboard"}
              class={[
                "btn",
                (@review_position && @game.review_mode == :end && "btn-ghost") || "btn-primary"
              ]}
            >
              <.icon name="hero-trophy" /> Zur Rangliste
            </.link>
          </div>
        </div>

        <%!-- Top-aligned while revealing (like the Review screen) so the stats
             panel extends downward without nudging the question above. --%>
        <div class={[
          "flex-1 min-h-0 flex flex-col items-center gap-8 p-8 lg:overflow-y-auto",
          (@game.revealing && "justify-start sm:pt-12") || "justify-center"
        ]}>
          <div :if={@game.status == :running} class="w-full max-w-3xl space-y-8">
            <div :if={@question} class="space-y-6">
              <p class="text-sm font-bold uppercase tracking-[0.18em] text-base-content/45">
                Frage {@q_number} / {@q_total}
              </p>
              <h2 class="text-4xl sm:text-5xl font-extrabold leading-tight text-primary">
                {@question.prompt}
              </h2>
              <.rich_text :if={@question.description not in [nil, ""]} html={@question.description} />

              <%!-- Collecting answers: live answered count. --%>
              <div :if={!@game.revealing} class="flex items-center gap-2 text-lg text-base-content/60">
                <.icon name="hero-user-group" class="size-5" />
                <span>
                  {@answered_count} / {length(@participants)} Teams haben geantwortet
                </span>
              </div>

              <%!-- Revealing: sample solution, plus the optional toggleable stats
                   panel (same pattern as the end-of-game Review screen). --%>
              <div :if={@game.revealing} class="space-y-6">
                <SolutionArea.solution_area question={@question} />

                <div :if={@game.show_statistics} class="pt-2">
                  <button
                    :if={!@show_stats}
                    type="button"
                    phx-click="toggle_stats"
                    class="btn btn-soft"
                  >
                    <.icon name="hero-chart-bar" class="size-5" /> Statistik einblenden
                  </button>

                  <div class={[
                    "grid transition-[grid-template-rows] duration-300 ease-out motion-reduce:transition-none",
                    (@show_stats && "grid-rows-[1fr]") || "grid-rows-[0fr]"
                  ]}>
                    <div class="overflow-hidden">
                      <div class={[
                        "space-y-3 transition-opacity duration-300 ease-out motion-reduce:transition-none",
                        (@show_stats && "opacity-100") || "opacity-0"
                      ]}>
                        <div class="flex items-center justify-between">
                          <h3 class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
                            Statistik
                          </h3>
                          <button type="button" phx-click="toggle_stats" class="btn btn-ghost btn-sm">
                            <.icon name="hero-chevron-up" class="size-4" /> Ausblenden
                          </button>
                        </div>
                        <StatsArea.stats_area stats={@stats} />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <p :if={!@question} class="text-lg text-base-content/60">Keine Frage verfügbar.</p>
          </div>

          <div :if={@game.status in [:finished, :closed]} class="text-center space-y-4">
            <.icon name="hero-flag" class="size-16 text-primary" />
            <p class="text-3xl font-bold">Quiz beendet.</p>
            <p :if={@review_position} class="text-lg text-base-content/60">
              Geh die Lösungen mit allen durch – danach geht's zur Rangliste.
            </p>
          </div>
        </div>
      </div>

      <%!-- Right 1/3: full-height, self-scrolling team roster --%>
      <aside class="lg:w-1/3 flex flex-col min-h-0 bg-base-200 border-t lg:border-t-0 lg:border-l border-base-300">
        <div class="shrink-0 flex items-center justify-between h-[84px] px-6 border-b border-base-300">
          <h2 class="text-lg font-bold">Teams</h2>
          <span class="badge badge-primary badge-lg font-display font-extrabold">
            {length(@participants)}
          </span>
        </div>

        <p
          :if={@participants == []}
          class="p-6 text-center text-sm text-base-content/60"
        >
          Warte auf die ersten Teams …
        </p>

        <ul id="participants-roster" class="flex-1 min-h-0 overflow-y-auto p-6 space-y-2 list-none">
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
     |> assign(:participants, Play.list_participants(game))
     |> assign(:review_position, first_review_position(socket.assigns.current_scope, game))
     |> load_question()}
  end

  @impl true
  def handle_event("start", _params, socket) do
    case Play.start_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} ->
        {:noreply, socket |> assign(:game, game) |> load_question()}

      {:error, :no_questions} ->
        {:noreply, put_flash(socket, :error, "Dieses Quiz hat noch keine Fragen.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Das Quiz konnte nicht gestartet werden.")}
    end
  end

  def handle_event("advance", _params, socket) do
    case Play.advance_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} ->
        {:noreply, socket |> assign(:game, game) |> load_question()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Konnte nicht zur nächsten Frage wechseln.")}
    end
  end

  def handle_event("reveal", _params, socket) do
    case Play.reveal_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} ->
        {:noreply, socket |> assign(:game, game) |> load_question()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Die Frage konnte nicht ausgewertet werden.")}
    end
  end

  def handle_event("toggle_stats", _params, socket) do
    {:noreply, update(socket, :show_stats, &(!&1))}
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    {:noreply, assign(socket, :participants, socket.assigns.participants ++ [participant])}
  end

  def handle_info({:status_changed, game}, socket) do
    {:noreply, socket |> assign(:game, game) |> load_question()}
  end

  def handle_info({:answer_submitted, _position}, socket) do
    {:noreply, assign_answered_count(socket)}
  end

  defp load_question(socket) do
    game = socket.assigns.game
    {number, total} = Play.question_numbering(game)
    question = Play.current_question(game)

    socket
    |> assign(:question, question)
    |> assign(:q_number, number)
    |> assign(:q_total, total)
    |> assign_answered_count()
    |> assign_reveal_stats(game, question)
  end

  # While revealing in `per_question` mode, compute the answer distribution (same
  # as the Review screen) and start with the panel collapsed. Each reveal/advance
  # routes through here, so the toggle naturally resets per question.
  defp assign_reveal_stats(socket, %{revealing: true, show_statistics: true}, question)
       when not is_nil(question) do
    total = length(socket.assigns.participants)

    socket
    |> assign(:stats, Stats.question_stats(question, total))
    |> assign(:show_stats, false)
  end

  defp assign_reveal_stats(socket, _game, _question) do
    socket
    |> assign(:stats, nil)
    |> assign(:show_stats, false)
  end

  defp assign_answered_count(socket) do
    game = socket.assigns.game
    assign(socket, :answered_count, Play.count_answers(game, game.current_position))
  end

  # Position of the first question, where the solution walkthrough starts, or nil
  # when the quiz has no questions (then there is nothing to review).
  defp first_review_position(scope, game) do
    case Games.list_questions_for_game(scope, game) do
      [] -> nil
      [first | _] -> first.position
    end
  end

  defp qr_svg(game) do
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
