defmodule QuizWeb.RunLive.Review do
  @moduledoc """
  Presenter-only solution walkthrough for a finished run.

  After a quiz ends, the moderator steps through every question on the big screen,
  revealing each one's sample solution, before sending the room to the leaderboard.
  Each question is its own URL (`/games/:id/review/:position`), so a projector
  reload or a LiveView reconnect keeps the moderator's place — unlike a transient
  in-memory cursor.

  Participants are untouched. The only thing written is the presentation state
  (`Quiz.Play.set_screen/3`), so a separate presentation window
  (`QuizWeb.RunLive.Screen`) follows along. Solutions are read straight off the
  authoring data via `QuizWeb.QuestionLive.SolutionArea`.
  """
  use QuizWeb, :live_view

  alias Quiz.{Games, Play, Stats}
  alias QuizWeb.RunLive.Stage

  @impl true
  def render(assigns) do
    ~H"""
    <Stage.keyboard />

    <div class="flex flex-col h-screen overflow-hidden bg-base-100">
      <%!-- Header (brand · title · primary action), mirroring the run view. --%>
      <div class="shrink-0 flex items-center justify-between gap-4 h-[84px] px-6 border-b border-base-300">
        <div class="flex items-center gap-4 min-w-0">
          <Stage.brand />
          <div class="min-w-0">
            <h1 class="text-lg font-bold truncate">{@game.title}</h1>
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
              Lösung · Frage {@number} / {@total}
            </p>
          </div>
        </div>

        <%!-- Step Zurück / Weiter through the questions, then "Zur Rangliste" on the last. --%>
        <div class="flex items-center gap-2 shrink-0">
          <Stage.shortcuts_button />
          <.link navigate={~p"/games/#{@game}/run"} class="btn btn-ghost">
            <.icon name="hero-x-mark" class="size-4" /> Besprechung beenden
          </.link>

          <.link
            :if={@prev_position}
            navigate={~p"/games/#{@game}/review/#{@prev_position}"}
            title="Zurück (←)"
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
            title="Weiter (→)"
            class="btn btn-primary"
          >
            Weiter <.icon name="hero-arrow-right" />
          </.link>
          <.link
            :if={!@next_position}
            navigate={~p"/games/#{@game}/leaderboard"}
            title="Zur Rangliste (→)"
            class="btn btn-primary"
          >
            <.icon name="hero-trophy" /> Zur Rangliste
          </.link>
        </div>
      </div>

      <%!-- Top-aligned (not vertically centered) so revealing the statistics
           extends downward without nudging the question/solution above. --%>
      <div class="flex-1 min-h-0 flex flex-col items-center justify-start gap-8 p-8 sm:pt-12 overflow-y-auto">
        <div class="w-full max-w-3xl">
          <Stage.question
            question={@question}
            revealing
            show_statistics={@game.show_statistics}
            show_stats={@game.screen_show_stats}
            stats={@stats}
            controls
          />
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_stats", _params, socket), do: {:noreply, toggle_stats(socket)}

  # Keyboard shortcuts (see `Stage.keyboard/1`): step through the
  # questions like the Zurück / Weiter links, and on to the leaderboard.
  def handle_event("shortcut", %{"action" => action}, socket) do
    %{game: game, prev_position: prev, next_position: next} = socket.assigns

    socket =
      case action do
        "next" when is_nil(next) ->
          push_navigate(socket, to: ~p"/games/#{game}/leaderboard")

        "next" ->
          push_navigate(socket, to: ~p"/games/#{game}/review/#{next}")

        "prev" when not is_nil(prev) ->
          push_navigate(socket, to: ~p"/games/#{game}/review/#{prev}")

        "stats" when game.show_statistics ->
          toggle_stats(socket)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  defp toggle_stats(socket) do
    %{current_scope: scope, game: game} = socket.assigns
    {:ok, game} = Play.set_screen(scope, game, %{screen_show_stats: !game.screen_show_stats})
    assign(socket, :game, game)
  end

  @impl true
  def mount(%{"id" => id, "position" => position}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)
    questions = Games.list_run_questions(socket.assigns.current_scope, game)
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

        # Point the presentation window at this question, statistics collapsed.
        game =
          if connected?(socket) do
            {:ok, game} =
              Play.set_screen(socket.assigns.current_scope, game, %{
                screen_view: :review,
                screen_position: position,
                screen_show_stats: false
              })

            game
          else
            game
          end

        {:ok,
         socket
         |> assign(:page_title, "Lösung: Frage #{index + 1}")
         |> assign(:game, game)
         |> assign(:question, question)
         |> assign(:number, index + 1)
         |> assign(:total, length(questions))
         |> assign(:prev_position, position_at(questions, index - 1))
         |> assign(:next_position, position_at(questions, index + 1))
         |> assign_stats(game, question)}
    end
  end

  # Stats are computed only when the game opts in. Each question is its own URL
  # (a fresh mount), which resets the reveal toggle per question.
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
