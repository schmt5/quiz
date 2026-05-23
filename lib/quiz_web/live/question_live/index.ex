defmodule QuizWeb.QuestionLive.Index do
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.Question

  @valid_types ~w(single_choice text_input)

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
              <li>Fragen</li>
            </ul>
          </div>
          <div class="flex items-center gap-2">
            <div class="tooltip tooltip-right" data-tip="Zurück zum Quiz">
              <.link
                navigate={~p"/games/#{@game}"}
                class="btn btn-ghost btn-sm btn-square"
                aria-label="Zurück zum Quiz"
              >
                <.icon name="hero-arrow-left" class="size-4" />
              </.link>
            </div>
            <h1 class="text-2xl font-bold">{@game.title} Fragen</h1>
          </div>
        </div>
      </:page_header>
      <div class="mx-auto max-w-7xl h-full py-6">
        <div class="flex gap-6 h-full">
          <aside class="w-72 shrink-0 flex flex-col rounded-box bg-base-200 h-full overflow-hidden">
            <div class="flex items-center justify-between px-4 pt-4 pb-3 border-b border-base-200">
              <span class="text-xs font-mono uppercase tracking-wider text-base-content/70">
                Fragen
              </span>
              <span class="text-xs font-mono text-base-content/60">
                {padded_count(@questions)}
              </span>
            </div>

            <div class="flex-1 p-4 overflow-y-auto">
              <div
                :if={@questions == []}
                class="rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
              >
                Noch keine Fragen — <br />füge rechts deine erste hinzu.
              </div>

              <ul :if={@questions != []} id="questions" class="space-y-1">
                <li
                  :for={{question, idx} <- Enum.with_index(@questions)}
                  id={"questions-#{question.id}"}
                >
                  <.link
                    patch={~p"/games/#{@game}/questions/#{question}/edit"}
                    class={[
                      "block rounded-md px-3 py-2 transition border",
                      selected?(@selected_question, question) &&
                        "border-base-content/30 bg-base-200",
                      !selected?(@selected_question, question) &&
                        "border-transparent hover:bg-base-200/60"
                    ]}
                  >
                    <div class="flex items-baseline gap-3">
                      <span class="font-mono text-xs text-base-content/60">
                        {pad(idx + 1)}
                      </span>
                      <span class="truncate text-sm">{question.prompt}</span>
                    </div>
                  </.link>
                </li>
              </ul>
            </div>

            <div class="p-3 border-t border-base-200 flex items-center gap-2">
              <.link
                patch={~p"/games/#{@game}/questions"}
                class="btn btn-soft flex-1"
              >
                <.icon name="hero-plus" /> Frage hinzufügen
              </.link>
              <div
                :if={length(@questions) > 1}
                class="tooltip tooltip-left"
                data-tip="Fragen sortieren"
              >
                <.link
                  navigate={~p"/games/#{@game}/questions/reorder"}
                  class="btn btn-soft btn-square"
                  aria-label="Fragen sortieren"
                >
                  <.icon name="hero-arrows-up-down" class="size-5" />
                </.link>
              </div>
            </div>
          </aside>

          <section class="flex-1 min-w-0 h-full overflow-y-auto">
            <.type_picker :if={@live_action == :index} game={@game} />
            <.question_form
              :if={@live_action in [:new, :edit]}
              form={@form}
              game={@game}
              live_action={@live_action}
              question_type={@question_type}
              selected_question={@selected_question}
            />
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :game, :map, required: true

  defp type_picker(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl py-12 text-center">
      <p class="text-xs font-mono uppercase tracking-wider text-base-content/60">
        Starte mit einer Frage
      </p>
      <h1 class="mt-3 text-3xl sm:text-4xl font-bold">
        Welche Art von Frage möchtest du hinzufügen?
      </h1>

      <div class="mt-10 grid grid-cols-1 sm:grid-cols-2 gap-4 text-left">
        <.link
          patch={~p"/games/#{@game}/questions/new?type=single_choice"}
          class="group rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            S
          </div>
          <h2 class="mt-4 text-lg font-bold">Single-Choice</h2>
          <p class="text-sm text-base-content/60">Eine richtige Antwort</p>
          <div class="mt-4 space-y-2">
            <div class="flex items-center gap-2">
              <span class="inline-block size-3 rounded-full border border-base-300"></span>
              <span class="block h-2 w-2/3 rounded bg-base-200"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="inline-block size-3 rounded-full bg-base-content"></span>
              <span class="block h-2 w-1/2 rounded bg-base-200"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="inline-block size-3 rounded-full border border-base-300"></span>
              <span class="block h-2 w-2/5 rounded bg-base-200"></span>
            </div>
          </div>
        </.link>

        <.link
          patch={~p"/games/#{@game}/questions/new?type=text_input"}
          class="group rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            T
          </div>
          <h2 class="mt-4 text-lg font-bold">Texteingabe</h2>
          <p class="text-sm text-base-content/60">Freie Eingabe</p>
          <div class="mt-8">
            <div class="h-8 w-2/3 rounded bg-base-200"></div>
          </div>
        </.link>
      </div>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :game, :map, required: true
  attr :live_action, :atom, required: true
  attr :question_type, :atom, required: true
  attr :selected_question, :map, required: true

  defp question_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="question-form"
      phx-change="validate"
      phx-submit="save"
      class="rounded-box bg-base-100 p-6"
    >
      <div class="flex items-center justify-between gap-4 pb-4 border-b border-base-200">
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            {type_letter(@question_type)}
          </div>
          <div>
            <p class="text-xs font-mono uppercase tracking-wider text-base-content/60">
              {form_eyebrow(@live_action)}
            </p>
            <h1 class="text-lg font-bold">{humanize_type(@question_type)}</h1>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <.link patch={~p"/games/#{@game}/questions"} class="btn btn-ghost">
            Abbrechen
          </.link>
          <div :if={@live_action == :edit} class="tooltip tooltip-bottom" data-tip="Frage löschen">
            <.link
              phx-click="delete"
              data-confirm="Diese Frage löschen?"
              class="btn btn-soft btn-error btn-square"
              aria-label="Frage löschen"
            >
              <.icon name="hero-trash" class="size-5" />
            </.link>
          </div>
          <.button phx-disable-with="Speichert..." variant="primary">Frage speichern</.button>
        </div>
      </div>

      <div class="space-y-4 pt-4">
        <input type="hidden" name="question[type]" value={Atom.to_string(@question_type)} />
        <input type="hidden" name="question[position]" value={@selected_question.position} />

        <.input field={@form[:prompt]} type="textarea" label="Fragetext" />

        <.inputs_for :let={d} field={@form[:data]}>
          <%= case @question_type do %>
            <% :single_choice -> %>
              <fieldset class="mt-8 space-y-3">
                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Antwortoptionen · Wähle die richtige aus</span>
                  <span>{choices_summary(@form)}</span>
                </div>

                <ul
                  id="choices-sortable"
                  phx-hook=".SortableChoices"
                  class="space-y-2 list-none p-0"
                >
                  <.inputs_for :let={c} field={d[:choices]}>
                    <li
                      id={"choice-#{c.index}"}
                      class={[
                        "choice-row group flex items-center gap-2 rounded-box bg-base-200 px-2 py-2 transition",
                        choice_correct?(c) && "ring-2 ring-success ring-inset"
                      ]}
                    >
                      <input
                        type="hidden"
                        name="question[data][choices_sort][]"
                        value={c.index}
                      />

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

                      <span class={[
                        "flex items-center justify-center size-8 rounded-md font-mono font-bold text-sm shrink-0",
                        choice_correct?(c) && "bg-success/20 text-success",
                        !choice_correct?(c) && "bg-base-100 text-base-content/70"
                      ]}>
                        {choice_letter(c.index)}
                      </span>

                      <input
                        type="text"
                        name={c[:text].name}
                        id={c[:text].id}
                        value={c[:text].value}
                        placeholder="Antworttext"
                        class="flex-1 bg-transparent border-none outline-none focus:ring-0 text-sm py-1"
                      />

                      <input type="hidden" name={c[:correct].name} value="false" />
                      <label class={[
                        "flex items-center gap-2 px-2 cursor-pointer text-xs",
                        choice_correct?(c) && "text-success font-semibold"
                      ]}>
                        <input
                          type="checkbox"
                          name={c[:correct].name}
                          id={c[:correct].id}
                          value="true"
                          checked={choice_correct?(c)}
                          class="peer sr-only"
                        />
                        <span class="size-5 rounded-full border-2 border-base-300 grid place-items-center transition peer-checked:bg-success peer-checked:border-success">
                          <span class="text-white text-[10px] leading-none opacity-0 peer-checked:opacity-100">
                            ✓
                          </span>
                        </span>
                        <span :if={choice_correct?(c)}>Richtig</span>
                      </label>

                      <button
                        type="button"
                        name="question[data][choices_drop][]"
                        value={c.index}
                        phx-click={JS.dispatch("change")}
                        class="text-base-content/40 hover:text-error px-2 text-lg leading-none"
                        aria-label="Option entfernen"
                      >
                        ×
                      </button>
                    </li>
                  </.inputs_for>
                </ul>

                <input type="hidden" name="question[data][choices_drop][]" />

                <button
                  type="button"
                  name="question[data][choices_sort][]"
                  value="new"
                  phx-click={JS.dispatch("change")}
                  class="w-full rounded-box border border-dashed border-base-300 px-3 py-3 text-sm text-base-content/70 hover:border-base-content/40 hover:text-base-content transition flex items-center justify-center gap-1"
                >
                  <span class="text-base">+</span> Option hinzufügen
                </button>

                <p :if={choices_error = data_field_error(@form, :choices)} class="text-error text-sm">
                  {choices_error}
                </p>

                <script :type={Phoenix.LiveView.ColocatedHook} name=".SortableChoices">
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
                        const form = el.closest("form");
                        if (form) form.dispatchEvent(new Event("change", { bubbles: true }));
                        dragging = null;
                      });
                    },
                    destroyed() { this.observer?.disconnect(); }
                  };
                </script>
              </fieldset>
            <% :text_input -> %>
              <fieldset class="mt-8 space-y-3">
                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Akzeptierte Lösungen · Jede Übereinstimmung zählt</span>
                  <span>{solutions_summary(@form)}</span>
                </div>

                <ul class="space-y-2 list-none p-0">
                  <.inputs_for :let={s} field={d[:solutions]}>
                    <li
                      id={"solution-#{s.index}"}
                      class="flex items-center gap-2 rounded-box bg-base-200 px-3 py-2"
                    >
                      <input
                        type="hidden"
                        name="question[data][solutions_sort][]"
                        value={s.index}
                      />

                      <input
                        type="text"
                        name={s[:text].name}
                        id={s[:text].id}
                        value={s[:text].value}
                        placeholder="Akzeptierte Antwort"
                        class="flex-1 bg-transparent border-none outline-none focus:ring-0 text-sm py-1"
                      />

                      <button
                        type="button"
                        name="question[data][solutions_drop][]"
                        value={s.index}
                        phx-click={JS.dispatch("change")}
                        class="text-base-content/40 hover:text-error px-2 text-lg leading-none"
                        aria-label="Lösung entfernen"
                      >
                        ×
                      </button>
                    </li>
                  </.inputs_for>
                </ul>

                <input type="hidden" name="question[data][solutions_drop][]" />

                <button
                  type="button"
                  name="question[data][solutions_sort][]"
                  value="new"
                  phx-click={JS.dispatch("change")}
                  class="w-full rounded-box border border-dashed border-base-300 px-3 py-3 text-sm text-base-content/70 hover:border-base-content/40 hover:text-base-content transition flex items-center justify-center gap-1"
                >
                  <span class="text-base">+</span> Lösung hinzufügen
                </button>

                <p
                  :if={solutions_error = data_field_error(@form, :solutions)}
                  class="text-error text-sm"
                >
                  {solutions_error}
                </p>
              </fieldset>
          <% end %>
        </.inputs_for>
      </div>

    </.form>
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
     |> assign(:game, game)
     |> assign(:questions, questions)
     |> assign(:selected_question, nil)
     |> assign(:question_type, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Fragen")
    |> assign(:selected_question, nil)
    |> assign(:question_type, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new, params) do
    case parse_type(params["type"]) do
      nil ->
        socket
        |> put_flash(:error, "Wähle einen Fragetyp.")
        |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")

      type ->
        question = %Question{
          user_id: socket.assigns.current_scope.user.id,
          game_id: socket.assigns.game.id,
          type: type,
          position: next_position(socket.assigns.questions)
        }

        changeset = Games.change_question(socket.assigns.current_scope, question)

        socket
        |> assign(:page_title, "Neue Frage")
        |> assign(:selected_question, question)
        |> assign(:question_type, type)
        |> assign(:form, to_form(changeset))
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    question = Games.get_question!(socket.assigns.current_scope, id)
    changeset = Games.change_question(socket.assigns.current_scope, question)

    socket
    |> assign(:page_title, "Frage bearbeiten")
    |> assign(:selected_question, question)
    |> assign(:question_type, question.type)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("validate", %{"question" => question_params}, socket) do
    changeset =
      Games.change_question(
        socket.assigns.current_scope,
        socket.assigns.selected_question,
        question_params
      )

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"question" => question_params}, socket) do
    save_question(socket, socket.assigns.live_action, question_params)
  end

  def handle_event("delete", _params, socket) do
    question = socket.assigns.selected_question
    {:ok, _} = Games.delete_question(socket.assigns.current_scope, question)

    {:noreply,
     socket
     |> put_flash(:info, "Frage gelöscht")
     |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")}
  end

  defp save_question(socket, :edit, question_params) do
    case Games.update_question(
           socket.assigns.current_scope,
           socket.assigns.selected_question,
           question_params
         ) do
      {:ok, question} ->
        {:noreply,
         socket
         |> put_flash(:info, "Frage erfolgreich aktualisiert")
         |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions/#{question}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_question(socket, :new, question_params) do
    question_params = Map.put(question_params, "game_id", socket.assigns.game.id)

    case Games.create_question(socket.assigns.current_scope, question_params) do
      {:ok, question} ->
        {:noreply,
         socket
         |> put_flash(:info, "Frage erfolgreich erstellt")
         |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions/#{question}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:reordered, _game}, socket) do
    questions = Games.list_questions_for_game(socket.assigns.current_scope, socket.assigns.game)
    {:noreply, assign(socket, :questions, questions)}
  end

  def handle_info({type, %Question{}}, socket) when type in [:created, :updated, :deleted] do
    questions = Games.list_questions_for_game(socket.assigns.current_scope, socket.assigns.game)

    socket = assign(socket, :questions, questions)

    socket =
      case {socket.assigns.live_action, socket.assigns.selected_question} do
        {:edit, %{id: id}} ->
          if Enum.any?(questions, &(&1.id == id)) do
            socket
          else
            socket
            |> put_flash(:error, "Die aktuelle Frage wurde gelöscht.")
            |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")
          end

        _ ->
          socket
      end

    {:noreply, socket}
  end

  defp parse_type(type) when type in @valid_types, do: String.to_existing_atom(type)
  defp parse_type(_), do: nil

  defp next_position([]), do: 1

  defp next_position(questions),
    do: Enum.map(questions, & &1.position) |> Enum.max() |> Kernel.+(1)

  defp padded_count(questions), do: pad(length(questions))
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp selected?(nil, _question), do: false
  defp selected?(%{id: id}, %{id: id}), do: true
  defp selected?(_, _), do: false

  defp humanize_type(:single_choice), do: "Single-Choice"
  defp humanize_type(:text_input), do: "Texteingabe"
  defp humanize_type(other), do: to_string(other)

  defp type_letter(:single_choice), do: "S"
  defp type_letter(:text_input), do: "T"
  defp type_letter(_), do: "?"

  defp form_eyebrow(:new), do: "Neue Frage"
  defp form_eyebrow(:edit), do: "Bearbeiten"

  defp choice_letter(index) when index in 0..25, do: <<?A + index>>
  defp choice_letter(_), do: "?"

  defp choice_correct?(c) do
    case c[:correct].value do
      true -> true
      "true" -> true
      _ -> false
    end
  end

  defp choices_summary(%{source: %Ecto.Changeset{} = cs}) do
    choices =
      case Ecto.Changeset.get_field(cs, :data) do
        %{choices: list} when is_list(list) -> list
        _ -> []
      end

    total = length(choices)
    correct = Enum.count(choices, &(&1.correct == true))
    "#{total} Optionen · #{correct} richtig"
  end

  defp choices_summary(_), do: "0 Optionen · 0 richtig"

  defp solutions_summary(%{source: %Ecto.Changeset{} = cs}) do
    solutions =
      case Ecto.Changeset.get_field(cs, :data) do
        %{solutions: list} when is_list(list) -> list
        _ -> []
      end

    "#{length(solutions)} Lösungen"
  end

  defp solutions_summary(_), do: "0 Lösungen"

  defp data_field_error(form, field) do
    case form.source.changes[:data] do
      %Ecto.Changeset{errors: errors} ->
        case Keyword.get(errors, field) do
          {msg, _opts} -> msg
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
