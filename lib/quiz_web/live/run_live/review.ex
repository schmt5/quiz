defmodule QuizWeb.RunLive.Review do
  @moduledoc """
  Presenter-only solution walkthrough for a finished run.

  After a quiz ends, the moderator steps through every question on the big screen,
  revealing each one's sample solution, before sending the room to the leaderboard.
  Each question is its own URL (`/games/:id/review/:position`), so a projector
  reload or a LiveView reconnect keeps the moderator's place — unlike a transient
  in-memory cursor.

  Read-only: nothing is broadcast and participants are untouched. Solutions are
  read straight off the authoring data via `QuizWeb.QuestionLive.SolutionArea`.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play, Stats}
  alias QuizWeb.QuestionLive.{SolutionArea, StatsArea}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen overflow-hidden bg-base-100">
      <%!-- Header (brand · title · primary action), mirroring the run view. --%>
      <div class="shrink-0 flex items-center justify-between gap-4 h-[84px] px-6 border-b border-base-300">
        <div class="flex items-center gap-4 min-w-0">
          <.link
            navigate={~p"/"}
            class="inline-flex items-baseline text-2xl font-extrabold tracking-tight shrink-0"
          >
            <span class="text-primary">Pub</span>
            <span class="bg-primary text-secondary rounded-xl px-2 py-0.5">Quiz</span>
          </.link>
          <div class="min-w-0">
            <h1 class="text-lg font-bold truncate">{@game.title}</h1>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
              Lösung · Frage {@number} / {@total}
            </p>
          </div>
        </div>

        <%!-- Step Zurück / Weiter through the questions, then "Zur Rangliste" on the last. --%>
        <div class="flex items-center gap-2 shrink-0">
          <.link navigate={~p"/games/#{@game}/run"} class="btn btn-ghost">
            <.icon name="hero-x-mark" class="size-4" /> Besprechung beenden
          </.link>

          <.link
            :if={@prev_position}
            navigate={~p"/games/#{@game}/review/#{@prev_position}"}
            class="btn btn-soft"
          >
            <.icon name="hero-arrow-left" /> Zurück
          </.link>
          <span :if={!@prev_position} class="btn btn-soft btn-disabled">
            <.icon name="hero-arrow-left" /> Zurück
          </span>

          <.link
            :if={@next_position}
            navigate={~p"/games/#{@game}/review/#{@next_position}"}
            class="btn btn-primary"
          >
            Weiter <.icon name="hero-arrow-right" />
          </.link>
          <.link
            :if={!@next_position}
            navigate={~p"/games/#{@game}/leaderboard"}
            class="btn btn-primary"
          >
            <.icon name="hero-trophy" /> Zur Rangliste
          </.link>
        </div>
      </div>

      <%!-- Top-aligned (not vertically centered) so revealing the statistics
           extends downward without nudging the question/solution above. --%>
      <div class="flex-1 min-h-0 flex flex-col items-center justify-start gap-8 p-8 sm:pt-12 overflow-y-auto">
        <div class="w-full max-w-3xl space-y-6">
          <h2 class="text-4xl sm:text-5xl font-extrabold leading-tight text-primary">
            {@question.prompt}
          </h2>
          <.rich_text :if={@question.description not in [nil, ""]} html={@question.description} />
          <SolutionArea.solution_area question={@question} />

          <%!-- Optional anonymous answer distribution, revealed on demand and kept
               visually separate from the solution above. The panel stays in the
               DOM and animates open via a grid-rows 0fr->1fr collapse, so the
               reveal eases instead of popping (respects reduced-motion). --%>
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
    </div>
    """
  end

  @impl true
  def handle_event("toggle_stats", _params, socket) do
    {:noreply, update(socket, :show_stats, &(!&1))}
  end

  @impl true
  def mount(%{"id" => id, "position" => position}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)
    questions = Games.list_questions_for_game(socket.assigns.current_scope, game)
    position = parse_position(position)

    case position && Enum.find_index(questions, &(&1.position == position)) do
      # No questions, or an unknown/garbage position: bounce to a sensible place.
      nil ->
        case questions do
          [] ->
            {:ok, push_navigate(socket, to: ~p"/games/#{game}/run")}

          [first | _] ->
            {:ok, push_navigate(socket, to: ~p"/games/#{game}/review/#{first.position}")}
        end

      index ->
        question = Enum.at(questions, index)

        {:ok,
         socket
         |> assign(:page_title, "Lösung: Frage #{index + 1}")
         |> assign(:game, game)
         |> assign(:question, question)
         |> assign(:number, index + 1)
         |> assign(:total, length(questions))
         |> assign(:prev_position, position_at(questions, index - 1))
         |> assign(:next_position, position_at(questions, index + 1))
         |> assign(:show_stats, false)
         |> assign_stats(game, question)}
    end
  end

  # Stats are computed only when the game opts in. Each question is its own URL
  # (a fresh mount), so the reveal toggle naturally resets per question.
  defp assign_stats(socket, %{show_statistics: true} = game, question) do
    total = length(Play.list_participants(game))
    assign(socket, :stats, Stats.question_stats(question, total))
  end

  defp assign_stats(socket, _game, _question), do: assign(socket, :stats, nil)

  defp position_at(questions, index) when index >= 0 do
    case Enum.at(questions, index) do
      nil -> nil
      question -> question.position
    end
  end

  defp position_at(_questions, _index), do: nil

  # A crafted, non-numeric :position must redirect (handled by the nil branch),
  # not crash the mount with an ArgumentError.
  defp parse_position(position) do
    case Integer.parse(position) do
      {pos, ""} -> pos
      _ -> nil
    end
  end
end
