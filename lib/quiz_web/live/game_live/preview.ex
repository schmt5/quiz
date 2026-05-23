defmodule QuizWeb.GameLive.Preview do
  use QuizWeb, :live_view

  alias Quiz.Games

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

          <.answer_area question={current_question(@questions, @index)} />

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

  attr :question, :map, required: true

  defp answer_area(%{question: %{type: :text_input}} = assigns) do
    ~H"""
    <input
      type="text"
      placeholder="Deine Antwort"
      class="input input-bordered w-full"
    />
    """
  end

  defp answer_area(%{question: %{type: :single_choice}} = assigns) do
    ~H"""
    <ul class="space-y-2 list-none p-0">
      <li :for={{choice, idx} <- Enum.with_index(@question.data.choices)}>
        <label class="flex items-center gap-3 rounded-box bg-base-200 px-3 py-2 cursor-pointer hover:bg-base-300 transition">
          <input
            type="radio"
            name={"choice-#{@question.id}"}
            value={idx}
            class="radio radio-primary"
          />
          <span class="text-sm">{choice.text}</span>
        </label>
      </li>
    </ul>
    """
  end

  defp answer_area(%{question: %{type: :sequence}} = assigns) do
    ~H"""
    <ul
      id={"preview-sequence-#{@question.id}"}
      phx-hook=".PreviewSortable"
      phx-update="ignore"
      class="space-y-2 list-none p-0"
    >
      <li
        :for={item <- @question.data.items}
        class="flex items-center gap-2 rounded-box bg-base-200 px-3 py-2"
      >
        <button
          type="button"
          data-handle
          aria-label="Sortieren"
          class="cursor-grab active:cursor-grabbing text-base-content/40 hover:text-base-content/70 px-1 select-none touch-none"
        >
          <svg class="size-4" viewBox="0 0 20 20" fill="currentColor">
            <circle cx="7" cy="5" r="1.5" />
            <circle cx="13" cy="5" r="1.5" />
            <circle cx="7" cy="10" r="1.5" />
            <circle cx="13" cy="10" r="1.5" />
            <circle cx="7" cy="15" r="1.5" />
            <circle cx="13" cy="15" r="1.5" />
          </svg>
        </button>
        <span class="text-sm">{item.text}</span>
      </li>
    </ul>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PreviewSortable">
      export default {
        mounted() {
          const el = this.el;
          let dragging = null;

          const bindHandles = () => {
            el.querySelectorAll("[data-handle]").forEach((h) => {
              if (h.dataset.bound) return;
              h.dataset.bound = "1";
              const li = h.closest("li");
              h.addEventListener("mousedown", () => li.setAttribute("draggable", "true"));
              h.addEventListener("mouseup", () => li.removeAttribute("draggable"));
              h.addEventListener("mouseleave", () => li.removeAttribute("draggable"));
            });
          };
          bindHandles();
          this.observer = new MutationObserver(bindHandles);
          this.observer.observe(el, { childList: true });

          el.addEventListener("dragstart", (e) => {
            const li = e.target.closest("li");
            if (!li || li.parentElement !== el) return;
            dragging = li;
            li.classList.add("opacity-40");
            e.dataTransfer.effectAllowed = "move";
            try { e.dataTransfer.setData("text/plain", ""); } catch (_) {}
          });

          el.addEventListener("dragover", (e) => {
            if (!dragging) return;
            e.preventDefault();
            const siblings = [...el.querySelectorAll("li:not(.opacity-40)")];
            const after = siblings.find((s) => {
              const r = s.getBoundingClientRect();
              return e.clientY < r.top + r.height / 2;
            });
            if (after) {
              if (after !== dragging.nextSibling) el.insertBefore(dragging, after);
            } else {
              if (el.lastElementChild !== dragging) el.appendChild(dragging);
            }
          });

          el.addEventListener("dragend", () => {
            if (!dragging) return;
            dragging.classList.remove("opacity-40");
            dragging.removeAttribute("draggable");
            dragging = null;
          });
        },
        destroyed() { this.observer?.disconnect(); }
      };
    </script>
    """
  end

  defp answer_area(assigns) do
    ~H"""
    <p class="text-sm text-base-content/60">Unbekannter Fragetyp.</p>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, game_id)

    questions =
      socket.assigns.current_scope
      |> Games.list_questions_for_game(game)
      |> Enum.map(&prepare_question/1)

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

  defp prepare_question(%{type: :sequence, data: data} = question) do
    %{question | data: %{data | items: Enum.shuffle(data.items)}}
  end

  defp prepare_question(question), do: question

  defp current_question(questions, index), do: Enum.at(questions, index)

  defp humanize_total(index, questions) do
    total = length(questions)
    "#{pad(index + 1)} / #{pad(total)}"
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
