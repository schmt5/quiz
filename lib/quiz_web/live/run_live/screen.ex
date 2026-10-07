defmodule QuizWeb.RunLive.Screen do
  @moduledoc """
  Guest-facing presentation window for a run, meant for the projector.

  It has no controls: it follows the operator's control window
  (`QuizWeb.RunLive.Host`, `QuizWeb.RunLive.Review`, `QuizWeb.LeaderboardLive.Show`)
  purely through the run's broadcasts — the lobby, every question and its
  reveal, then the closing screen, the solution walkthrough and the
  leaderboard. Where the room is after the quiz is read from the game's
  persisted screen state (`screen_view`, see `Quiz.Play.set_screen/3`), so a
  reloaded projector picks up at the right place.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play, Stats}
  alias QuizWeb.LeaderboardComponent
  alias QuizWeb.RunLive.Stage

  @impl true
  def render(assigns) do
    ~H"""
    <div id="screen" class="min-h-screen bg-base-100">
      <Stage.lobby
        :if={@game.status == :open}
        game={@game}
        participants={@participants}
        qr_svg={@qr_svg}
      />

      <div :if={@game.status != :open} class="flex flex-col h-screen overflow-hidden">
        <div class="shrink-0 flex items-center justify-between gap-4 h-[84px] px-6 border-b border-base-300">
          <div class="flex items-center gap-4 min-w-0">
            <Stage.brand link={false} />
            <h1 class="text-lg font-bold truncate">{@game.title}</h1>
          </div>
          <p
            :if={@heading}
            class="shrink-0 text-xs font-bold uppercase tracking-[0.18em] text-base-content/45"
          >
            {@heading}
          </p>
        </div>

        <div class={[
          "flex-1 min-h-0 flex flex-col items-center gap-8 p-8 overflow-y-auto",
          (@stage in [:question, :review] && @revealing && "justify-start sm:pt-12") ||
            (@stage == :leaderboard && "justify-start") || "justify-center"
        ]}>
          <%= case @stage do %>
            <% :waiting -> %>
              <p id="screen-waiting" class="text-2xl font-bold text-base-content/60">
                Gleich geht's los …
              </p>
            <% stage when stage in [:question, :review] -> %>
              <div class="w-full max-w-3xl">
                <Stage.question
                  question={@question}
                  label={@label}
                  revealing={@revealing}
                  answered_count={(@stage == :question && @answered_count) || nil}
                  participant_count={length(@participants)}
                  show_statistics={@game.show_statistics}
                  show_stats={@game.screen_show_stats}
                  stats={@stats}
                />
              </div>
            <% :finished -> %>
              <Stage.finished game={@game} has_questions={@has_questions} />
            <% :leaderboard -> %>
              <div id="screen-leaderboard" class="w-full max-w-xl space-y-8">
                <div
                  :if={!@game.grading_published}
                  class="flex flex-col items-center gap-4 rounded-3xl bg-base-200 p-10 text-center"
                >
                  <span class="loading loading-dots loading-lg text-primary"></span>
                  <p class="text-xl font-bold">Korrektur in Bearbeitung</p>
                  <p class="text-base-content/60">
                    Die Rangliste erscheint, sobald die Wertung veröffentlicht ist.
                  </p>
                </div>

                <LeaderboardComponent.standings :if={@game.grading_published} rows={@rows} />
              </div>
          <% end %>
        </div>

        <%!-- Late teams can still join while the quiz runs. --%>
        <div
          :if={@game.status == :running}
          class="fixed bottom-6 right-6 rounded-2xl bg-base-100 p-3 pr-5 shadow-lg ring-1 ring-base-300"
        >
          <Stage.join_badge game={@game} qr_svg={@qr_svg} />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    game = Games.get_game!(scope, id)

    if connected?(socket), do: Play.subscribe(game)

    {:ok,
     socket
     |> assign(:page_title, "Präsentation: #{game.title}")
     |> assign(:game, game)
     |> assign(:qr_svg, Stage.qr_svg(game))
     |> assign(:questions, Games.list_questions_for_game(scope, game))
     |> assign(:participants, Play.list_participants(game))
     |> load_stage()}
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    # Same dedup as the host: a team can enroll between subscribe and the
    # initial participant list.
    if Enum.any?(socket.assigns.participants, &(&1.id == participant.id)) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :participants, socket.assigns.participants ++ [participant])}
    end
  end

  def handle_info({:participant_removed, participant}, socket) do
    {:noreply,
     socket
     |> assign(
       :participants,
       Enum.reject(socket.assigns.participants, &(&1.id == participant.id))
     )
     |> assign_answered_count()}
  end

  def handle_info({msg, game}, socket) when msg in [:status_changed, :screen_changed] do
    {:noreply, socket |> assign(:game, game) |> load_stage()}
  end

  def handle_info({:answer_submitted, _position}, socket) do
    {:noreply, assign_answered_count(socket)}
  end

  def handle_info({:grading_published, game, rows}, socket) do
    {:noreply, socket |> assign(:game, game) |> assign(:rows, rows)}
  end

  # Never crash the projector on a broadcast this view doesn't act on.
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Derives everything the current stage needs from the game: which stage
  # (`:waiting`, `:question`, `:finished`, `:review`, `:leaderboard`), the
  # question on display, its label and the statistics.
  defp load_stage(socket) do
    %{game: game, questions: questions} = socket.assigns

    {stage, question, label} =
      case {game.status, game.screen_view} do
        {:running, _} ->
          {number, total} = Play.question_numbering(game)
          {:question, Play.current_question(game), "Frage #{number} / #{total}"}

        {status, :review} when status in [:finished, :closed] ->
          case Enum.find_index(questions, &(&1.position == game.screen_position)) do
            nil ->
              {:finished, nil, nil}

            index ->
              {:review, Enum.at(questions, index),
               "Lösung · Frage #{index + 1} / #{length(questions)}"}
          end

        {status, :leaderboard} when status in [:finished, :closed] ->
          {:leaderboard, nil, nil}

        {status, _} when status in [:finished, :closed] ->
          {:finished, nil, nil}

        _ ->
          {:waiting, nil, nil}
      end

    # A running game without a current question has nothing to show yet.
    stage = if stage == :question and is_nil(question), do: :waiting, else: stage
    revealing = stage == :review or (stage == :question and game.revealing)

    socket
    |> assign(:stage, stage)
    |> assign(:question, question)
    |> assign(:label, (stage == :question && label) || nil)
    |> assign(:heading, (stage == :review && label) || (stage == :leaderboard && "Rangliste"))
    |> assign(:revealing, revealing)
    |> assign(:has_questions, questions != [])
    |> assign(:stats, stats(game, question, revealing, length(socket.assigns.participants)))
    |> assign(:rows, rows(stage, game))
    |> assign_answered_count()
  end

  defp stats(%{show_statistics: true}, question, true, total) when not is_nil(question),
    do: Stats.question_stats(question, total)

  defp stats(_game, _question, _revealing, _total), do: nil

  defp rows(:leaderboard, %{grading_published: true} = game), do: Play.leaderboard(game)
  defp rows(_stage, _game), do: []

  defp assign_answered_count(socket) do
    game = socket.assigns.game
    assign(socket, :answered_count, Play.count_answers(game, game.current_position))
  end
end
