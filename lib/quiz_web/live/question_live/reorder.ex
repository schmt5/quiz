defmodule QuizWeb.QuestionLive.Reorder do
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.Question

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:page_header>
        <div class="mx-auto max-w-7xl">
          <div class="breadcrumbs text-xs">
            <ul>
              <li>
                <.link navigate={~p"/"} aria-label="Home">
                  <.icon name="hero-home" class="size-4" />
                </.link>
              </li>
              <li><.link navigate={~p"/games"}>Quizze</.link></li>
              <li><.link navigate={~p"/games/#{@game}"}>{@game.title}</.link></li>
              <li><.link navigate={~p"/games/#{@game}/questions"}>Fragen</.link></li>
              <li>Sortieren</li>
            </ul>
          </div>
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-2">
              <div class="tooltip tooltip-right" data-tip="Zurück zu den Fragen">
                <.link
                  navigate={~p"/games/#{@game}/questions"}
                  class="btn btn-ghost btn-sm btn-square"
                  aria-label="Zurück zu den Fragen"
                >
                  <.icon name="hero-arrow-left" class="size-4" />
                </.link>
              </div>
              <h1 class="text-2xl font-bold">Fragen sortieren</h1>
            </div>
            <.link
              href={~p"/games/#{@game}/preview"}
              target="_blank"
              rel="noopener"
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-eye" /> Vorschau
            </.link>
          </div>
        </div>
      </:page_header>

      <div class="mx-auto max-w-3xl py-6">
        <div class="rounded-box bg-base-100 p-6">
          <div class="flex items-center justify-between gap-4 pb-4 border-b border-base-200">
            <p class="text-sm text-base-content/70">
              Ziehe Fragen am Griff, um sie zu sortieren.
            </p>
            <div class="flex items-center gap-2">
              <.link navigate={~p"/games/#{@game}/questions"} class="btn btn-ghost">
                Abbrechen
              </.link>
              <.button
                type="button"
                phx-click="save"
                phx-disable-with="Speichert..."
                variant="primary"
              >
                Reihenfolge speichern
              </.button>
            </div>
          </div>

          <div
            :if={ordered_questions(@questions, @order) == []}
            class="mt-6 rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
          >
            Keine Fragen zum Sortieren.
          </div>

          <ul
            :if={ordered_questions(@questions, @order) != []}
            id="questions-sortable"
            phx-hook=".SortableQuestions"
            class="mt-4 space-y-2 list-none p-0"
          >
            <li
              :for={{question, idx} <- Enum.with_index(ordered_questions(@questions, @order))}
              id={"questions-#{question.id}"}
              class="question-row flex items-center gap-3 rounded-box bg-base-200 px-3 py-3 transition"
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

              <span class="flex items-center justify-center size-8 rounded-md font-mono font-bold text-sm shrink-0 bg-base-100 text-base-content/70">
                {pad(idx + 1)}
              </span>

              <span class="truncate text-sm flex-1">{question.prompt}</span>
            </li>
          </ul>

          <script :type={Phoenix.LiveView.ColocatedHook} name=".SortableQuestions">
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
                  const ids = [...el.querySelectorAll("li")].map((li) =>
                    li.id.replace(/^questions-/, "")
                  );
                  this.pushEvent("reorder", { ids });
                  dragging = null;
                });
              },
              destroyed() { this.observer?.disconnect(); }
            };
          </script>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    if connected?(socket) do
      Games.subscribe_questions(socket.assigns.current_scope)
    end

    game = Games.get_game!(socket.assigns.current_scope, game_id)
    questions = Games.list_questions_for_game(socket.assigns.current_scope, game)

    {:ok,
     socket
     |> assign(:page_title, "Fragen sortieren")
     |> assign(:game, game)
     |> assign(:questions, questions)
     |> assign(:order, Enum.map(questions, & &1.id))}
  end

  @impl true
  def handle_event("reorder", %{"ids" => ids}, socket) do
    normalized =
      ids
      |> Enum.map(&parse_id/1)
      |> Enum.reject(&is_nil/1)

    valid_ids = MapSet.new(socket.assigns.questions, & &1.id)

    if MapSet.new(normalized) == valid_ids and length(normalized) == MapSet.size(valid_ids) do
      {:noreply, assign(socket, :order, normalized)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save", _params, socket) do
    case Games.reposition_questions(
           socket.assigns.current_scope,
           socket.assigns.game,
           socket.assigns.order
         ) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Reihenfolge der Fragen gespeichert")
         |> push_navigate(to: ~p"/games/#{socket.assigns.game}/questions")}

      {:error, :invalid} ->
        {:noreply, put_flash(socket, :error, "Die neue Reihenfolge konnte nicht gespeichert werden.")}
    end
  end

  @impl true
  def handle_info({:reordered, _game}, socket) do
    refresh(socket)
  end

  def handle_info({type, %Question{}}, socket) when type in [:created, :updated, :deleted] do
    refresh(socket)
  end

  defp refresh(socket) do
    questions = Games.list_questions_for_game(socket.assigns.current_scope, socket.assigns.game)

    {:noreply,
     socket
     |> assign(:questions, questions)
     |> assign(:order, Enum.map(questions, & &1.id))}
  end

  defp ordered_questions(questions, order) do
    by_id = Map.new(questions, &{&1.id, &1})

    order
    |> Enum.map(&Map.get(by_id, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_id(_), do: nil
end
