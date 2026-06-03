defmodule QuizWeb.GameLive.Preview do
  use QuizWeb, :live_view

  alias Quiz.Games
  alias QuizWeb.QuestionLive.AnswerArea

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex flex-col items-center justify-center gap-4 py-8">
      <div class="w-[390px] h-[700px] bg-base-100 rounded-3xl shadow-xl ring-1 ring-base-300 flex flex-col overflow-hidden">
        <div
          :if={@questions == []}
          class="flex-1 grid place-items-center text-base-content/60 p-6 text-center"
        >
          Noch keine Fragen in diesem Quiz.
        </div>

        <div :if={@questions != []} class="flex-1 flex flex-col p-6 gap-4 overflow-y-auto">
          <p class="font-mono text-xs uppercase tracking-wider text-base-content/60">
            Frage {humanize_total(@index, @questions)}
          </p>
          <h2 class="text-xl font-bold">{current_question(@questions, @index).prompt}</h2>

          <.rich_text html={current_question(@questions, @index).description} />

          <AnswerArea.answer_area question={current_question(@questions, @index)} />

          <div class="mt-auto pt-4">
            <button type="button" class="btn btn-primary btn-block">Senden</button>
          </div>
        </div>
      </div>

      <div :if={@questions != []} class="flex items-center gap-4">
        <button
          type="button"
          phx-click="prev"
          class="btn btn-soft btn-square"
          disabled={@index == 0}
          aria-label="Vorherige Frage"
        >
          <.icon name="hero-arrow-left" />
        </button>
        <span class="font-mono text-xs text-base-content/60">
          {humanize_total(@index, @questions)}
        </span>
        <button
          type="button"
          phx-click="next"
          class="btn btn-soft btn-square"
          disabled={@index == length(@questions) - 1}
          aria-label="Nächste Frage"
        >
          <.icon name="hero-arrow-right" />
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, game_id)

    questions =
      socket.assigns.current_scope
      |> Games.list_questions_for_game(game)
      |> Enum.map(&AnswerArea.prepare_question/1)

    {:ok,
     socket
     |> assign(:page_title, "Vorschau")
     |> assign(:game, game)
     |> assign(:questions, questions)
     |> assign(:index, 0)}
  end

  @impl true
  def handle_event("prev", _params, socket) do
    {:noreply, assign(socket, :index, max(socket.assigns.index - 1, 0))}
  end

  def handle_event("next", _params, socket) do
    max_index = max(length(socket.assigns.questions) - 1, 0)
    {:noreply, assign(socket, :index, min(socket.assigns.index + 1, max_index))}
  end

  defp current_question(questions, index), do: Enum.at(questions, index)

  defp humanize_total(index, questions) do
    total = length(questions)
    "#{pad(index + 1)} / #{pad(total)}"
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
