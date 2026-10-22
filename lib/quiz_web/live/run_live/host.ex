defmodule QuizWeb.RunLive.Host do
  @moduledoc """
  Operator "landing page" for a running quiz (the lobby). Shows the join code,
  a QR code linking to the enrollment page, and the live list of enrolled teams.
  From here the operator starts the quiz.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play, Stats}
  alias Quiz.Games.Game
  alias QuizWeb.QuestionLive.OptionsArea
  alias QuizWeb.RunLive.Stage

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Lobby (:open): two-pane presenter view matching the "wasdas?" mockup. --%>
    <Stage.lobby
      :if={@game.status == :open}
      game={@game}
      participants={@participants}
      qr_svg={@qr_svg}
      controls
    >
      <:actions>
        <button
          type="button"
          phx-click="start"
          disabled={@participants == []}
          class="btn btn-secondary btn-lg"
        >
          <.icon name="hero-play" /> Quiz starten
        </button>
        <.enrollment_toggle
          :if={!@game.enrollment_locked}
          game={@game}
          class="btn-lg text-base-100"
        />
        <.enrollment_toggle :if={@game.enrollment_locked} game={@game} class="btn-lg" />
        <button
          :if={Game.intro?(@game)}
          type="button"
          onclick="intro_modal.showModal()"
          title="Infos & Spielregeln"
          aria-label="Infos & Spielregeln"
          class="btn btn-ghost btn-circle btn-lg text-base-100"
        >
          <.icon name="hero-information-circle" class="size-8" />
        </button>
        <.screen_link game={@game} class="btn-lg text-base-100" />
        <.link navigate={~p"/games/#{@game}"} class="btn btn-ghost btn-sm text-base-100/70">
          <.icon name="hero-arrow-left" class="size-4" /> Zurück zum Quiz
        </.link>
      </:actions>
    </Stage.lobby>

    <.content_modal
      :if={@game.status == :open and Game.intro?(@game)}
      id="intro_modal"
      title="Infos & Spielregeln"
      text={@game.intro_text}
      image_key={@game.intro_image_key}
    />

    <Stage.keyboard :if={@game.status != :open} />

    <%!-- Running / finished: unchanged single-column operator view. --%>
    <div
      :if={@game.status != :open}
      class="flex flex-col lg:flex-row lg:h-screen lg:overflow-hidden bg-base-100"
    >
      <%!-- Left 2/3: header (brand · title · primary action), then question / result --%>
      <div class="lg:w-2/3 flex flex-col min-h-0 lg:overflow-hidden">
        <div class="shrink-0 flex items-center justify-between gap-4 h-[84px] px-6 border-b border-base-300">
          <div class="flex items-center gap-4 min-w-0">
            <Stage.brand />
            <h1 class="text-lg font-bold truncate">{@game.title}</h1>
          </div>

          <%!-- `per_question` mode inserts a reveal step: "Auswerten" closes the
               question and shows its solution/stats, then "Nächste Frage" advances.
               `end` mode advances straight away, exactly as before. "Vorherige Frage"
               sends the room back one question (disabled on the first) so teams can
               re-see and re-enter what they submitted. --%>
          <div :if={@game.status == :running} class="flex items-center gap-2 shrink-0">
            <Stage.shortcuts_button />
            <.screen_link game={@game} />
            <.enrollment_toggle game={@game} compact />

            <button
              type="button"
              phx-click="retreat"
              disabled={@q_number <= 1}
              title="Vorherige Frage (←)"
              class="btn btn-ghost"
            >
              <.icon name="hero-arrow-left" /> Vorherige Frage
            </button>

            <button
              :if={@game.review_mode == :per_question and not @game.revealing}
              type="button"
              phx-click="reveal"
              title="Auswerten (→)"
              class="btn btn-primary"
            >
              <.icon name="hero-light-bulb" /> Auswerten
            </button>

            <span
              :if={@finish_hint}
              id="finish-hint"
              class="text-sm font-semibold text-primary animate-pulse"
            >
              Zum Beenden klicken
            </span>
            <button
              :if={not (@game.review_mode == :per_question and not @game.revealing)}
              id="advance"
              type="button"
              phx-click="advance"
              title={if(@q_number >= @q_total, do: "Quiz beenden", else: "Nächste Frage (→)")}
              class={["btn btn-primary", @finish_hint && "ring-4 ring-secondary"]}
            >
              <%= if @q_number >= @q_total and @q_total > 0 do %>
                <.icon name="hero-flag" /> Quiz beenden
              <% else %>
                Nächste Frage <.icon name="hero-arrow-right" />
              <% end %>
            </button>
          </div>

          <div
            :if={@game.status in [:finished, :closed]}
            class="flex items-center gap-2 shrink-0"
          >
            <Stage.shortcuts_button :if={@review_position && @game.review_mode == :end} />
            <.screen_link game={@game} />
            <button
              :if={Game.outro?(@game)}
              type="button"
              onclick="outro_modal.showModal()"
              title="Abschluss & Infos"
              aria-label="Abschluss & Infos"
              class="btn btn-ghost btn-circle"
            >
              <.icon name="hero-information-circle" class="size-6" />
            </button>
            <.link
              :if={@review_position && @game.review_mode == :end}
              navigate={~p"/games/#{@game}/review/#{@review_position}"}
              title="Lösungen besprechen (→)"
              class="btn btn-ghost"
            >
              <.icon name="hero-light-bulb" /> Lösungen besprechen
            </.link>
            <.link
              :if={!@game.grading_published}
              navigate={~p"/games/#{@game}/correction"}
              class="btn btn-primary"
            >
              <.icon name="hero-check-circle" /> Korrigieren & veröffentlichen
            </.link>
            <.link
              navigate={~p"/games/#{@game}/leaderboard"}
              class={["btn", (@game.grading_published && "btn-primary") || "btn-ghost"]}
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
            <Stage.question
              :if={@question}
              question={@question}
              label={"Frage #{@q_number} / #{@q_total}"}
              revealing={@game.revealing}
              answered_count={@answered_count}
              participant_count={length(@participants)}
              show_statistics={@game.show_statistics}
              show_stats={@game.screen_show_stats}
              stats={@stats}
              controls
            />

            <p :if={!@question} class="text-lg text-base-content/60">Keine Frage verfügbar.</p>
          </div>

          <Stage.finished
            :if={@game.status in [:finished, :closed]}
            game={@game}
            has_questions={@review_position != nil}
          />
        </div>
      </div>

      <.content_modal
        :if={@game.status in [:finished, :closed] and Game.outro?(@game)}
        id="outro_modal"
        title="Abschluss & Infos"
        text={@game.outro_text}
        image_key={@game.outro_image_key}
      />

      <%!-- Right 1/3: while a question runs, tabs switch between a read-only
           preview of the answer options (what the teams see) and the team
           roster; otherwise just the roster. Both panes scroll on their own. --%>
      <aside class="lg:w-1/3 flex flex-col min-h-0 bg-base-200 border-t lg:border-t-0 lg:border-l border-base-300">
        <div class="shrink-0 flex items-center justify-between h-[84px] px-6 border-b border-base-300">
          <div
            :if={@options}
            role="tablist"
            aria-label="Seitenleiste"
            class="flex w-full gap-1 rounded-xl bg-base-300/60 p-1"
          >
            <.sidebar_tab id="sidebar-tab-options" tab="options" active={@sidebar_tab == :options}>
              <.icon name="hero-queue-list" class="size-5" /> Antworten
            </.sidebar_tab>
            <.sidebar_tab id="sidebar-tab-teams" tab="teams" active={@sidebar_tab == :teams}>
              <.icon name="hero-user-group" class="size-5" /> Teams
              <span class="badge badge-primary badge-sm font-display font-extrabold">
                {length(@participants)}
              </span>
            </.sidebar_tab>
          </div>

          <h2 :if={!@options} class="text-lg font-bold">Teams</h2>
          <span :if={!@options} class="badge badge-primary badge-lg font-display font-extrabold">
            {length(@participants)}
          </span>
        </div>

        <div
          :if={@options && @sidebar_tab == :options}
          id="sidebar-options"
          role="tabpanel"
          aria-labelledby="sidebar-tab-options"
          class="flex-1 min-h-0 overflow-y-auto p-6"
        >
          <OptionsArea.options_area options={@options} revealing={@game.revealing} />
        </div>

        <p
          :if={@participants == [] and (!@options || @sidebar_tab == :teams)}
          class="p-6 text-center text-sm text-base-content/60"
        >
          Warte auf die ersten Teams …
        </p>

        <ul
          :if={!@options || @sidebar_tab == :teams}
          id="participants-roster"
          role={@options && "tabpanel"}
          aria-labelledby={@options && "sidebar-tab-teams"}
          class="flex-1 min-h-0 overflow-y-auto p-6 space-y-2 list-none"
        >
          <li
            :for={participant <- @participants}
            id={"participant-#{participant.id}"}
            class="flex items-center gap-2 rounded-box bg-base-100 px-3 py-2"
          >
            <.icon name="hero-user-group" class="size-4 text-base-content/50" />
            <span class="text-sm font-medium truncate">{participant.name}</span>
            <button
              type="button"
              phx-click="remove_participant"
              phx-value-id={participant.id}
              data-confirm={"Team «#{participant.name}» wirklich entfernen? Bereits gegebene Antworten werden gelöscht."}
              title="Team entfernen"
              aria-label={"Team #{participant.name} entfernen"}
              class="ml-auto btn btn-ghost btn-xs btn-circle text-base-content/40 hover:text-error"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </li>
        </ul>

        <%!-- Fixer QR-Code, damit Nachzügler jederzeit beitreten können --%>
        <div class="shrink-0 border-t border-base-300 p-4">
          <Stage.join_badge game={@game} qr_svg={@qr_svg} />
        </div>
      </aside>
    </div>
    """
  end

  # One segment of the sidebar's tab switch ("Antworten" / "Teams").
  attr :id, :string, required: true
  attr :tab, :string, required: true
  attr :active, :boolean, required: true
  slot :inner_block, required: true

  defp sidebar_tab(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      role="tab"
      aria-selected={to_string(@active)}
      phx-click="select_tab"
      phx-value-tab={@tab}
      class={[
        "flex flex-1 items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-bold",
        "transition duration-200 motion-reduce:transition-none",
        if(@active,
          do: "bg-base-100 text-primary shadow-sm",
          else: "text-base-content/60 hover:bg-base-100/50 hover:text-base-content"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # Opens the guest-facing presentation (`RunLive.Screen`) in a new window, to be
  # dragged onto the projector while this one stays on the operator's screen.
  attr :game, Game, required: true
  attr :class, :string, default: nil

  defp screen_link(assigns) do
    ~H"""
    <.link
      id="open-screen"
      href={~p"/games/#{@game}/screen"}
      target="_blank"
      title="Präsentation in neuem Fenster öffnen und auf den Beamer ziehen"
      aria-label="Präsentation öffnen"
      class={["btn btn-ghost btn-circle", @class]}
    >
      <.icon name="hero-tv" class="size-6" />
    </.link>
    """
  end

  # Operator lever to stop / resume new enrollments (see `Play.enroll/2`). Shown
  # in both the lobby and the running header; `compact` renders it icon-only for
  # the tight running toolbar. The colour flips to `btn-warning` while locked so
  # the current state is obvious at a glance, and the label states the *action*.
  attr :game, Game, required: true
  attr :compact, :boolean, default: false
  attr :class, :string, default: nil

  defp enrollment_toggle(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="toggle_enrollment"
      title={
        if @game.enrollment_locked,
          do: "Anmeldung wieder öffnen",
          else: "Keine neuen Teams mehr zulassen"
      }
      aria-label={if @game.enrollment_locked, do: "Anmeldung öffnen", else: "Anmeldung sperren"}
      class={[
        "btn",
        if(@game.enrollment_locked, do: "btn-warning", else: "btn-ghost"),
        @compact && "btn-circle",
        @class
      ]}
    >
      <.icon name={if @game.enrollment_locked, do: "hero-lock-closed", else: "hero-lock-open"} />
      <span :if={!@compact}>
        {if @game.enrollment_locked, do: "Anmeldung öffnen", else: "Anmeldung sperren"}
      </span>
    </button>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    game = Games.get_game!(scope, id)

    game =
      if connected?(socket) do
        Play.subscribe(game)
        back_on_stage(scope, game)
      else
        game
      end

    {:ok,
     socket
     |> assign(:page_title, "Durchführung: #{game.title}")
     |> assign(:game, game)
     |> assign(:qr_svg, Stage.qr_svg(game))
     |> assign(:participants, Play.list_participants(game))
     |> assign(:review_position, first_review_position(socket.assigns.current_scope, game))
     |> assign(:sidebar_tab, :options)
     |> assign(:options, nil)
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

  def handle_event("advance", _params, socket), do: {:noreply, advance(socket)}
  def handle_event("retreat", _params, socket), do: {:noreply, retreat(socket)}
  def handle_event("reveal", _params, socket), do: {:noreply, reveal(socket)}

  # Keyboard / presenter clicker (see `Stage.keyboard/1`).
  def handle_event("shortcut", %{"action" => action}, socket) do
    {:noreply, shortcut(action, socket)}
  end

  # Deliberately not reset per question: once the operator picks a tab, it
  # stays picked until they switch back.
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    tab =
      case tab do
        "teams" -> :teams
        _ -> :options
      end

    {:noreply, assign(socket, :sidebar_tab, tab)}
  end

  def handle_event("toggle_stats", _params, socket), do: {:noreply, toggle_stats(socket)}

  def handle_event("toggle_enrollment", _params, socket) do
    game = socket.assigns.game

    case Play.set_enrollment_locked(
           socket.assigns.current_scope,
           game,
           !game.enrollment_locked
         ) do
      {:ok, game} ->
        {:noreply, assign(socket, :game, game)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Die Anmeldung konnte nicht umgeschaltet werden.")}
    end
  end

  def handle_event("remove_participant", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Enum.find(socket.assigns.participants, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      participant ->
        {:ok, _} =
          Play.remove_participant(socket.assigns.current_scope, socket.assigns.game, participant)

        {:noreply, socket}
    end
  end

  defp advance(socket) do
    case Play.advance_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} -> socket |> assign(:game, game) |> load_question()
      {:error, _} -> put_flash(socket, :error, "Konnte nicht zur nächsten Frage wechseln.")
    end
  end

  defp retreat(socket) do
    case Play.retreat_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} -> socket |> assign(:game, game) |> load_question()
      {:error, _} -> put_flash(socket, :error, "Konnte nicht zur vorherigen Frage wechseln.")
    end
  end

  defp reveal(socket) do
    case Play.reveal_run(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, game} -> socket |> assign(:game, game) |> load_question()
      {:error, _} -> put_flash(socket, :error, "Die Frage konnte nicht ausgewertet werden.")
    end
  end

  # The toggle lives on the game so the presentation window opens the panel too.
  defp toggle_stats(socket) do
    %{current_scope: scope, game: game} = socket.assigns
    {:ok, game} = Play.set_screen(scope, game, %{screen_show_stats: !game.screen_show_stats})
    assign(socket, :game, game)
  end

  # "Next" does whatever the primary header button does — except ending the
  # quiz, which can't be undone and so stays a deliberate click; the button is
  # highlighted instead.
  defp shortcut("next", %{assigns: %{game: %{status: :running} = game}} = socket) do
    cond do
      game.review_mode == :per_question and not game.revealing -> reveal(socket)
      last_question?(socket.assigns) -> assign(socket, :finish_hint, true)
      true -> advance(socket)
    end
  end

  defp shortcut("next", %{assigns: %{game: %{status: status} = game}} = socket)
       when status in [:finished, :closed] do
    case socket.assigns.review_position do
      position when not is_nil(position) and game.review_mode == :end ->
        push_navigate(socket, to: ~p"/games/#{game}/review/#{position}")

      _ ->
        socket
    end
  end

  defp shortcut("prev", %{assigns: %{game: %{status: :running}, q_number: number}} = socket)
       when number > 1,
       do: retreat(socket)

  defp shortcut(
         "stats",
         %{assigns: %{game: %{status: :running, revealing: true, show_statistics: true}}} = socket
       ),
       do: toggle_stats(socket)

  defp shortcut(_action, socket), do: socket

  defp last_question?(%{q_number: number, q_total: total}), do: total > 0 and number >= total

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    # Dedup: a team can enroll in the gap between subscribe/3 and the initial
    # list_participants/1 during mount, so it would arrive both in the loaded
    # list and via this broadcast — which would render a duplicate DOM id.
    if Enum.any?(socket.assigns.participants, &(&1.id == participant.id)) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :participants, socket.assigns.participants ++ [participant])}
    end
  end

  # Their answers were cascade-deleted with them, so the answered count may
  # have dropped too.
  def handle_info({:participant_removed, participant}, socket) do
    {:noreply,
     socket
     |> assign(
       :participants,
       Enum.reject(socket.assigns.participants, &(&1.id == participant.id))
     )
     |> assign_answered_count()}
  end

  def handle_info({:status_changed, game}, socket) do
    {:noreply, socket |> assign(:game, game) |> load_question()}
  end

  def handle_info({:screen_changed, game}, socket) do
    {:noreply, assign(socket, :game, game)}
  end

  def handle_info({:answer_submitted, _position}, socket) do
    {:noreply, assign_answered_count(socket)}
  end

  # The operator can publish the grading (from the correction view) while the
  # host/presenter screen is still open. Keep our game copy in sync; the screen
  # itself doesn't change, but this avoids crashing on the broadcast.
  def handle_info({:grading_published, game, _leaderboard}, socket) do
    {:noreply, assign(socket, :game, game)}
  end

  # Ignore any other run broadcasts we don't act on, so a new message type can
  # never crash the presenter screen mid-quiz.
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_question(socket) do
    game = socket.assigns.game
    {number, total} = Play.question_numbering(game)
    question = Play.current_question(game)

    socket
    |> assign(:question, question)
    |> assign(:finish_hint, false)
    |> assign(:q_number, number)
    |> assign(:q_total, total)
    |> assign_answered_count()
    |> assign_options(game, question)
    |> assign_reveal_stats(game, question)
  end

  # Read-only preview of the current question's answer options for the sidebar,
  # only while a question is live. Shuffled once per question (see
  # `OptionsArea.prepare/1`): the reveal reloads the same question, and the
  # projected order must not jump around in front of the room.
  defp assign_options(socket, %{status: :running}, %{id: id} = question) do
    case socket.assigns.options do
      %{question: %{id: ^id}} -> socket
      _ -> assign(socket, :options, OptionsArea.prepare(question))
    end
  end

  defp assign_options(socket, _game, _question), do: assign(socket, :options, nil)

  # While revealing in `per_question` mode, compute the answer distribution (same
  # as the Review screen). The panel's open state is `game.screen_show_stats`,
  # which every transition resets, so it starts collapsed on each question.
  defp assign_reveal_stats(socket, %{revealing: true, show_statistics: true}, question)
       when not is_nil(question) do
    total = length(socket.assigns.participants)
    assign(socket, :stats, Stats.question_stats(question, total))
  end

  defp assign_reveal_stats(socket, _game, _question), do: assign(socket, :stats, nil)

  defp assign_answered_count(socket) do
    game = socket.assigns.game
    assign(socket, :answered_count, Play.count_answers(game, game.current_position))
  end

  # Position of the first question, where the solution walkthrough starts, or nil
  # when the quiz has no questions (then there is nothing to review).
  defp first_review_position(scope, game) do
    case Games.list_run_questions(scope, game) do
      [] -> nil
      [first | _] -> first.position
    end
  end

  # Back on the run screen after the quiz (e.g. "Besprechung beenden" in the
  # walkthrough): the presentation window follows back to the closing screen.
  defp back_on_stage(scope, %Game{status: status} = game) when status in [:finished, :closed] do
    {:ok, game} = Play.set_screen(scope, game, %{screen_view: :run, screen_position: nil})
    game
  end

  defp back_on_stage(_scope, game), do: game
end
