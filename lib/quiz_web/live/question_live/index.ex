defmodule QuizWeb.QuestionLive.Index do
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.Question
  alias Quiz.Games.Question.Pin
  alias QuizWeb.QuestionLive.AnswerArea

  @valid_types ~w(single_choice text_input sequence pin_on_image matching)

  @run_locked_message "Dieses Quiz ist abgeschlossen – Fragen können nicht mehr bearbeitet werden."

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
          <div class="flex items-center justify-between gap-4">
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
            <div
              :if={@mode == :edit and @live_action == :edit}
              class="flex items-center gap-2"
            >
              <p
                :if={@save_status}
                class="flex items-center gap-1 text-sm text-error"
                role="alert"
              >
                <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
                {@save_status}
              </p>
              <button
                type="button"
                popovertarget="question-actions"
                class="btn btn-soft btn-square btn-sm"
                style="anchor-name:--question-actions"
                aria-label="Weitere Aktionen"
              >
                <.icon name="hero-ellipsis-vertical" class="size-5" />
              </button>
              <ul
                class="dropdown dropdown-end menu w-52 rounded-box bg-base-100 shadow-sm"
                popover
                id="question-actions"
                style="position-anchor:--question-actions"
              >
                <li>
                  <.link
                    phx-click="delete"
                    data-confirm="Diese Frage löschen?"
                    class="text-error"
                  >
                    <.icon name="hero-trash" class="size-5" /> Frage löschen
                  </.link>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </:page_header>
      <div class="mx-auto max-w-7xl h-full py-6">
        <div class="flex gap-6 h-full">
          <aside class="w-80 shrink-0 flex flex-col rounded-box bg-base-200 h-full overflow-hidden">
            <div :if={!@locked} class="p-3 border-b border-base-200">
              <div class="flex gap-1 p-1 rounded-lg bg-base-300/60">
                <button
                  type="button"
                  phx-click="set_mode"
                  phx-value-mode="edit"
                  class={[
                    "flex-1 inline-flex items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition",
                    @mode == :edit && "bg-base-100 shadow-sm text-base-content",
                    @mode != :edit && "text-base-content/60 hover:text-base-content"
                  ]}
                >
                  <.icon name="hero-pencil-square" class="size-4" /> Bearbeiten
                </button>
                <button
                  type="button"
                  phx-click="set_mode"
                  phx-value-mode="view"
                  class={[
                    "flex-1 inline-flex items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition",
                    @mode == :view && "bg-base-100 shadow-sm text-base-content",
                    @mode != :view && "text-base-content/60 hover:text-base-content"
                  ]}
                >
                  <.icon name="hero-eye" class="size-4" /> Ansehen
                </button>
              </div>
            </div>
            <div
              :if={@locked}
              class="m-3 flex items-start gap-2 rounded-box border border-warning/40 bg-warning/10 p-3 text-sm"
            >
              <.icon name="hero-lock-closed" class="size-5 shrink-0 text-warning" />
              <span>
                Dieses Quiz ist abgeschlossen. Fragen können nicht mehr bearbeitet werden, damit die Auswertung gültig bleibt.
              </span>
            </div>
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
                    :if={!@locked}
                    patch={~p"/games/#{@game}/questions/#{question}/edit"}
                    class={[
                      "block rounded-md px-3 py-2 transition border",
                      selected?(@selected_question, question) &&
                        "border-base-content/30 bg-base-200",
                      !selected?(@selected_question, question) &&
                        "border-transparent hover:bg-base-200/60"
                    ]}
                  >
                    <div class="flex items-center gap-2">
                      <span class="font-mono text-xs text-base-content/60">
                        {pad(idx + 1)}
                      </span>
                      <span class="flex items-center justify-center size-5 rounded bg-base-300 text-base-content/60 font-mono font-bold text-[10px] shrink-0">
                        {type_letter(question.type)}
                      </span>
                      <span class={[
                        "truncate text-sm",
                        blank?(question.prompt) && "italic text-base-content/50"
                      ]}>
                        {question_label(question)}
                      </span>
                    </div>
                  </.link>
                  <div
                    :if={@locked}
                    class="block rounded-md px-3 py-2 border border-transparent"
                  >
                    <div class="flex items-center gap-2">
                      <span class="font-mono text-xs text-base-content/60">
                        {pad(idx + 1)}
                      </span>
                      <span class="flex items-center justify-center size-5 rounded bg-base-300 text-base-content/60 font-mono font-bold text-[10px] shrink-0">
                        {type_letter(question.type)}
                      </span>
                      <span class={[
                        "truncate text-sm",
                        blank?(question.prompt) && "italic text-base-content/50"
                      ]}>
                        {question_label(question)}
                      </span>
                    </div>
                  </div>
                </li>
              </ul>
            </div>

            <div class="p-3 border-t border-base-200 flex items-center gap-2">
              <.link
                :if={!@locked}
                patch={~p"/games/#{@game}/questions"}
                class="btn btn-soft flex-1"
              >
                <.icon name="hero-plus" /> Frage hinzufügen
              </.link>
              <button
                type="button"
                popovertarget="panel-actions"
                class={["btn btn-soft btn-square", @locked && "flex-1"]}
                style="anchor-name:--panel-actions"
                aria-label="Weitere Aktionen"
              >
                <.icon name="hero-ellipsis-vertical" class="size-5" />
              </button>
              <ul
                class="dropdown dropdown-end menu w-52 rounded-box bg-base-100 shadow-sm"
                popover
                id="panel-actions"
                style="position-anchor:--panel-actions"
              >
                <li :if={!@locked and length(@questions) > 1}>
                  <.link navigate={~p"/games/#{@game}/questions/reorder"}>
                    <.icon name="hero-arrows-up-down" class="size-5" /> Fragen sortieren
                  </.link>
                </li>
                <li>
                  <.link href={~p"/games/#{@game}/preview"} target="_blank" rel="noopener">
                    <.icon name="hero-device-phone-mobile" class="size-5" /> Vorschau
                  </.link>
                </li>
              </ul>
            </div>
          </aside>

          <section class="flex-1 min-w-0 h-full overflow-y-auto">
            <div :if={@mode == :edit}>
              <.type_picker :if={@live_action == :index} game={@game} />
              <.question_form
                :if={@live_action == :edit}
                form={@form}
                game={@game}
                live_action={@live_action}
                question_type={@question_type}
                selected_question={@selected_question}
                uploads={@uploads}
              />
            </div>

            <div :if={@mode == :view} class="space-y-6 max-w-2xl">
              <div
                :if={@questions == []}
                class="rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
              >
                Noch keine Fragen in diesem Quiz.
              </div>
              <article
                :for={{q, idx} <- Enum.with_index(@questions)}
                class="group relative rounded-box border border-base-300 bg-base-100 p-6 space-y-4"
              >
                <button
                  :if={!@locked}
                  type="button"
                  phx-click="edit_question"
                  phx-value-id={q.id}
                  class="absolute top-3 right-3 btn btn-sm btn-square btn-soft opacity-0 group-hover:opacity-100 focus:opacity-100 transition"
                  aria-label="Frage bearbeiten"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </button>
                <p class="font-mono text-xs uppercase tracking-wider text-base-content/60">
                  Frage {pad(idx + 1)}
                </p>
                <h2 class="text-xl font-bold">{q.prompt}</h2>
                <.rich_text html={q.description} />
                <AnswerArea.answer_area question={AnswerArea.prepare_question(q)} />
              </article>
            </div>
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

      <div class="mt-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 text-left">
        <button
          type="button"
          phx-click="create"
          phx-value-type="single_choice"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
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
        </button>

        <button
          type="button"
          phx-click="create"
          phx-value-type="text_input"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            T
          </div>
          <h2 class="mt-4 text-lg font-bold">Texteingabe</h2>
          <p class="text-sm text-base-content/60">Freie Eingabe</p>
          <div class="mt-8">
            <div class="h-8 w-2/3 rounded bg-base-200"></div>
          </div>
        </button>

        <button
          type="button"
          phx-click="create"
          phx-value-type="sequence"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            R
          </div>
          <h2 class="mt-4 text-lg font-bold">Reihenfolge</h2>
          <p class="text-sm text-base-content/60">Einträge in richtiger Reihenfolge sortieren</p>
          <div class="mt-4 space-y-2">
            <div class="flex items-center gap-2">
              <span class="font-mono text-xs text-base-content/60">01</span>
              <span class="block h-2 w-2/3 rounded bg-base-200"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="font-mono text-xs text-base-content/60">02</span>
              <span class="block h-2 w-1/2 rounded bg-base-200"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="font-mono text-xs text-base-content/60">03</span>
              <span class="block h-2 w-2/5 rounded bg-base-200"></span>
            </div>
          </div>
        </button>

        <button
          type="button"
          phx-click="create"
          phx-value-type="pin_on_image"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            P
          </div>
          <h2 class="mt-4 text-lg font-bold">Pin auf Bild</h2>
          <p class="text-sm text-base-content/60">Ziel auf einem Bild markieren</p>
          <div class="mt-4">
            <div class="relative grid size-24 place-items-center rounded bg-base-200 overflow-hidden">
              <.icon name="hero-photo" class="size-full text-base-content/20" />
              <span class="absolute left-[42%] top-[60%] size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-error/30 ring-2 ring-error/50">
              </span>
              <span class="absolute left-[42%] top-[60%] size-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-error">
              </span>
            </div>
          </div>
        </button>

        <button
          type="button"
          phx-click="create"
          phx-value-type="matching"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            Z
          </div>
          <h2 class="mt-4 text-lg font-bold">Zuordnung</h2>
          <p class="text-sm text-base-content/60">Einträge einander zuordnen</p>
          <div class="mt-4 space-y-2">
            <div class="flex items-center gap-2">
              <span class="block h-2 w-1/3 rounded bg-base-200"></span>
              <span class="text-base-content/40 text-xs">↔</span>
              <span class="block h-2 w-1/3 rounded bg-base-content/20"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="block h-2 w-2/5 rounded bg-base-200"></span>
              <span class="text-base-content/40 text-xs">↔</span>
              <span class="block h-2 w-1/4 rounded bg-base-content/20"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="block h-2 w-1/4 rounded bg-base-200"></span>
              <span class="text-base-content/40 text-xs">↔</span>
              <span class="block h-2 w-2/5 rounded bg-base-content/20"></span>
            </div>
          </div>
        </button>
      </div>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :game, :map, required: true
  attr :live_action, :atom, required: true
  attr :question_type, :atom, required: true
  attr :selected_question, :map, required: true
  attr :uploads, :map, required: true

  defp question_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="question-form"
      phx-change="validate"
      phx-submit="save"
      phx-debounce="500"
      class="rounded-box bg-base-100 p-6"
    >
      <div class="space-y-4">
        <input type="hidden" name="question[type]" value={Atom.to_string(@question_type)} />
        <input type="hidden" name="question[position]" value={@selected_question.position} />

        <.input field={@form[:prompt]} type="textarea" label="Fragetext" />

        <%!-- Beschreibung component is hidden for now (both creating and editing); markup and
              logic are kept in place so it can be re-enabled later. --%>
        <div :if={false}>
          <label class="block text-sm font-semibold mb-1">
            Beschreibung <span class="font-normal text-base-content/50">(optional)</span>
          </label>
          <div
            id={"description-editor-#{@selected_question.id || "new"}"}
            phx-hook=".RichText"
            phx-update="ignore"
            class="rounded-box border border-base-300 bg-base-100 overflow-hidden focus-within:border-base-content/40 transition"
          >
            <div class="flex items-center gap-1 border-b border-base-300 bg-base-200/50 px-2 py-1.5">
              <button
                type="button"
                data-cmd="bold"
                class="btn btn-ghost btn-xs btn-square font-bold"
                title="Fett"
                aria-label="Fett"
              >
                B
              </button>
              <button
                type="button"
                data-cmd="italic"
                class="btn btn-ghost btn-xs btn-square italic"
                title="Kursiv"
                aria-label="Kursiv"
              >
                I
              </button>
              <span class="mx-1 h-4 w-px bg-base-300"></span>
              <button
                type="button"
                data-hl="hl-yellow"
                class="size-5 rounded border border-base-300 hl-yellow"
                title="Gelb hervorheben"
                aria-label="Gelb hervorheben"
              >
              </button>
              <button
                type="button"
                data-hl="hl-green"
                class="size-5 rounded border border-base-300 hl-green"
                title="Grün hervorheben"
                aria-label="Grün hervorheben"
              >
              </button>
              <button
                type="button"
                data-hl="hl-pink"
                class="size-5 rounded border border-base-300 hl-pink"
                title="Pink hervorheben"
                aria-label="Pink hervorheben"
              >
              </button>
              <span class="mx-1 h-4 w-px bg-base-300"></span>
              <button
                type="button"
                data-clear
                class="btn btn-ghost btn-xs btn-square"
                title="Formatierung entfernen"
                aria-label="Formatierung entfernen"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <div
              data-editor
              contenteditable="true"
              class="min-h-24 px-3 py-2 text-sm outline-none prose prose-sm max-w-none"
            >
            </div>
            <input
              type="hidden"
              name={@form[:description].name}
              id={@form[:description].id}
              value={@form[:description].value}
              data-input
            />
          </div>

          <script :type={Phoenix.LiveView.ColocatedHook} name=".RichText">
            export default {
              mounted() {
                this.editor = this.el.querySelector("[data-editor]");
                this.input = this.el.querySelector("[data-input]");
                this.editor.innerHTML = this.input.value || "";

                this.sync = () => {
                  this.input.value = this.editor.innerHTML;
                  this.el.closest("form")?.dispatchEvent(new Event("change", { bubbles: true }));
                };

                this.onInput = () => this.sync();
                this.editor.addEventListener("input", this.onInput);

                // Prevent the toolbar from stealing focus / collapsing the selection.
                this.onMouseDown = (e) => {
                  if (e.target.closest("button")) e.preventDefault();
                };
                this.el.addEventListener("mousedown", this.onMouseDown);

                this.onClick = (e) => {
                  const btn = e.target.closest("button");
                  if (!btn || !this.el.contains(btn)) return;
                  e.preventDefault();
                  this.editor.focus();
                  if (btn.dataset.cmd) {
                    document.execCommand(btn.dataset.cmd, false, null);
                  } else if (btn.dataset.hl) {
                    this.highlight(btn.dataset.hl);
                  } else if (btn.hasAttribute("data-clear")) {
                    document.execCommand("removeFormat", false, null);
                    this.unwrapMarks();
                  }
                  this.sync();
                };
                this.el.addEventListener("click", this.onClick);
              },

              highlight(cls) {
                const sel = window.getSelection();
                if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
                const range = sel.getRangeAt(0);
                if (!this.editor.contains(range.commonAncestorContainer)) return;
                const mark = document.createElement("mark");
                mark.className = cls;
                try {
                  range.surroundContents(mark);
                } catch (_) {
                  mark.appendChild(range.extractContents());
                  range.insertNode(mark);
                }
                sel.removeAllRanges();
              },

              unwrapMarks() {
                const sel = window.getSelection();
                if (!sel || sel.rangeCount === 0) return;
                const range = sel.getRangeAt(0);
                this.editor.querySelectorAll("mark").forEach((m) => {
                  if (range.intersectsNode(m)) {
                    const parent = m.parentNode;
                    while (m.firstChild) parent.insertBefore(m.firstChild, m);
                    parent.removeChild(m);
                  }
                });
              },

              destroyed() {
                this.editor?.removeEventListener("input", this.onInput);
                this.el.removeEventListener("mousedown", this.onMouseDown);
                this.el.removeEventListener("click", this.onClick);
              },
            };
          </script>
        </div>

        <.inputs_for :let={d} field={@form[:data]}>
          <%= case @question_type do %>
            <% :single_choice -> %>
              <fieldset class="mt-8 space-y-3">
                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Antwortoptionen · Wähle die richtige aus</span>
                  <span>{choices_summary(@form)}</span>
                </div>

                <ul class="space-y-2 list-none p-0">
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
            <% :sequence -> %>
              <fieldset class="mt-4 space-y-3">
                <div role="alert" class="alert alert-info alert-soft">
                  <.icon name="hero-information-circle" class="size-5 shrink-0" />
                  <span class="text-sm">
                    Die Reihenfolge ist die Lösung. Teilnehmende sehen die Einträge in zufälliger Reihenfolge und müssen sie in die richtige Ordnung bringen.
                  </span>
                </div>

                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Einträge · Reihenfolge ist die Lösung</span>
                  <span>{items_summary(@form)}</span>
                </div>

                <ul
                  id="items-sortable"
                  phx-hook=".SortableItems"
                  class="space-y-2 list-none p-0"
                >
                  <.inputs_for :let={i} field={d[:items]}>
                    <li
                      id={"item-#{i.index}"}
                      class="item-row group flex items-center gap-2 rounded-box bg-base-200 px-2 py-2 transition"
                    >
                      <input
                        type="hidden"
                        name="question[data][items_sort][]"
                        value={i.index}
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

                      <input
                        type="text"
                        name={i[:text].name}
                        id={i[:text].id}
                        value={i[:text].value}
                        placeholder="Eintrag"
                        class="flex-1 bg-transparent border-none outline-none focus:ring-0 text-sm py-1"
                      />

                      <button
                        type="button"
                        name="question[data][items_drop][]"
                        value={i.index}
                        phx-click={JS.dispatch("change")}
                        class="text-base-content/40 hover:text-error px-2 text-lg leading-none"
                        aria-label="Eintrag entfernen"
                      >
                        ×
                      </button>
                    </li>
                  </.inputs_for>
                </ul>

                <input type="hidden" name="question[data][items_drop][]" />

                <button
                  type="button"
                  name="question[data][items_sort][]"
                  value="new"
                  phx-click={JS.dispatch("change")}
                  class="w-full rounded-box border border-dashed border-base-300 px-3 py-3 text-sm text-base-content/70 hover:border-base-content/40 hover:text-base-content transition flex items-center justify-center gap-1"
                >
                  <span class="text-base">+</span> Eintrag hinzufügen
                </button>

                <p :if={items_error = data_field_error(@form, :items)} class="text-error text-sm">
                  {items_error}
                </p>

                <script :type={Phoenix.LiveView.ColocatedHook} name=".SortableItems">
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
            <% :pin_on_image -> %>
              <% entry = List.first(@uploads.pin_image.entries) %>
              <% image_key = pin_image_key(@form) %>
              <fieldset class="mt-8 space-y-4">
                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Hintergrundbild · Setze das Ziel</span>
                  <span>{pin_summary(@form)}</span>
                </div>

                <div
                  class="rounded-box border border-dashed border-base-300 p-4"
                  phx-drop-target={@uploads.pin_image.ref}
                >
                  <div class="flex items-center justify-between gap-4">
                    <div class="text-sm text-base-content/70">
                      <p class="font-semibold">
                        {if entry || image_key, do: "Bild ersetzen", else: "Bild hochladen"}
                      </p>
                      <p class="text-xs text-base-content/50">
                        JPG, PNG oder WEBP · max. 5 MB. Ziehe eine Datei hierher oder wähle sie aus.
                      </p>
                    </div>
                    <label class="btn btn-soft btn-sm">
                      <.icon name="hero-arrow-up-tray" class="size-4" /> Datei wählen
                      <.live_file_input upload={@uploads.pin_image} class="sr-only" />
                    </label>
                  </div>

                  <p
                    :for={err <- upload_errors(@uploads.pin_image)}
                    class="mt-2 text-error text-sm"
                  >
                    {upload_error_to_string(err)}
                  </p>
                  <p
                    :for={entry <- @uploads.pin_image.entries}
                    :if={err = List.first(upload_errors(@uploads.pin_image, entry))}
                    class="mt-2 text-error text-sm"
                  >
                    {upload_error_to_string(err)}
                  </p>
                </div>

                <input
                  type="hidden"
                  name="question[data][pin][image_key]"
                  value={image_key}
                />

                <div :if={entry || image_key} class="space-y-3">
                  <p class="text-xs text-base-content/60">
                    Klicke auf das Bild, um das Ziel zu setzen. Mit dem Regler unten passt du
                    den Toleranzradius an.
                  </p>

                  <div
                    id="pin-editor"
                    phx-hook=".PinEditor"
                    data-target-x={pin_coord(@form, :target_x)}
                    data-target-y={pin_coord(@form, :target_y)}
                    data-radius={pin_coord(@form, :radius)}
                    data-aspect-ratio={pin_coord(@form, :aspect_ratio)}
                    class="relative w-full max-w-md overflow-hidden rounded-box bg-base-200 cursor-crosshair select-none"
                    style={"aspect-ratio: #{pin_coord(@form, :aspect_ratio)};"}
                  >
                    <.live_img_preview
                      :if={entry}
                      entry={entry}
                      class="absolute inset-0 w-full h-full object-cover pointer-events-none"
                    />
                    <img
                      :if={!entry && image_key}
                      src={Quiz.Storage.url(image_key)}
                      class="absolute inset-0 w-full h-full object-cover pointer-events-none"
                      alt="Hintergrundbild"
                    />
                    <div
                      id="pin-editor-layer"
                      phx-update="ignore"
                      class="absolute inset-0 pointer-events-none"
                    >
                    </div>
                  </div>

                  <label class="flex items-center gap-3 text-sm max-w-md">
                    <span class="shrink-0 text-base-content/70">Radius</span>
                    <input
                      type="range"
                      name="question[data][pin][radius]"
                      min="0.02"
                      max="0.5"
                      step="0.01"
                      value={pin_coord(@form, :radius)}
                      class="range range-primary range-sm flex-1"
                    />
                  </label>

                  <input
                    type="hidden"
                    name="question[data][pin][target_x]"
                    value={pin_coord(@form, :target_x)}
                  />
                  <input
                    type="hidden"
                    name="question[data][pin][target_y]"
                    value={pin_coord(@form, :target_y)}
                  />
                  <input
                    type="hidden"
                    name="question[data][pin][aspect_ratio]"
                    value={pin_coord(@form, :aspect_ratio)}
                  />
                </div>

                <p :if={pin_error = data_field_error(@form, :pin)} class="text-error text-sm">
                  {pin_error}
                </p>

                <script :type={Phoenix.LiveView.ColocatedHook} name=".PinEditor">
                  export default {
                    mounted() {
                      this.form = this.el.closest("form");
                      this.layer = this.el.querySelector("#pin-editor-layer");

                      this.circle = document.createElement("div");
                      this.circle.className =
                        "absolute rounded-full bg-error/20 border-2 border-error/60 -translate-x-1/2 -translate-y-1/2";
                      this.marker = document.createElement("div");
                      this.marker.className =
                        "absolute size-3 rounded-full bg-error ring-2 ring-white shadow -translate-x-1/2 -translate-y-1/2";
                      this.layer.appendChild(this.circle);
                      this.layer.appendChild(this.marker);

                      this.onClick = (e) => {
                        const r = this.el.getBoundingClientRect();
                        const x = Math.min(Math.max((e.clientX - r.left) / r.width, 0), 1);
                        const y = Math.min(Math.max((e.clientY - r.top) / r.height, 0), 1);
                        this.setInput("target_x", x);
                        this.setInput("target_y", y);
                        this.render(x, y, this.radiusValue());
                        this.dispatchChange();
                      };
                      this.el.addEventListener("click", this.onClick);

                      this.radiusEl = this.input("radius");
                      this.onRadius = () =>
                        this.render(this.coord("target_x"), this.coord("target_y"), this.radiusValue());
                      if (this.radiusEl) this.radiusEl.addEventListener("input", this.onRadius);

                      this.bindImage();
                      this.render(this.coord("target_x"), this.coord("target_y"), this.radiusValue());
                    },

                    updated() {
                      this.bindImage();
                      this.render(this.coord("target_x"), this.coord("target_y"), this.radiusValue());
                    },

                    destroyed() {
                      this.el.removeEventListener("click", this.onClick);
                      if (this.radiusEl) this.radiusEl.removeEventListener("input", this.onRadius);
                    },

                    input(field) {
                      return this.form?.querySelector(
                        `[name="question[data][pin][${field}]"]`
                      );
                    },
                    setInput(field, value) {
                      const el = this.input(field);
                      if (el) el.value = value;
                    },
                    coord(field) {
                      const el = this.input(field);
                      const v = el ? parseFloat(el.value) : NaN;
                      return Number.isFinite(v) ? v : parseFloat(this.el.dataset[field === "target_x" ? "targetX" : "targetY"]) || 0.5;
                    },
                    radiusValue() {
                      const v = this.radiusEl ? parseFloat(this.radiusEl.value) : NaN;
                      return Number.isFinite(v) ? v : parseFloat(this.el.dataset.radius) || 0.1;
                    },
                    aspectRatio() {
                      const el = this.input("aspect_ratio");
                      const v = el ? parseFloat(el.value) : NaN;
                      return Number.isFinite(v) && v > 0
                        ? v
                        : parseFloat(this.el.dataset.aspectRatio) || 1;
                    },
                    // Read the natural aspect ratio of the uploaded/stored image
                    // and propagate it to the hidden input and the box so the
                    // whole image shows uncropped and scoring matches the view.
                    bindImage() {
                      const img = this.el.querySelector("img");
                      if (!img) return;
                      const capture = () => {
                        if (!img.naturalWidth || !img.naturalHeight) return;
                        const ar = img.naturalWidth / img.naturalHeight;
                        this.setInput("aspect_ratio", ar);
                        this.el.style.aspectRatio = ar;
                        this.render(
                          this.coord("target_x"),
                          this.coord("target_y"),
                          this.radiusValue()
                        );
                      };
                      if (img.complete && img.naturalWidth) capture();
                      else img.addEventListener("load", capture, { once: true });
                    },
                    render(x, y, radius) {
                      const ar = this.aspectRatio();
                      this.marker.style.left = x * 100 + "%";
                      this.marker.style.top = y * 100 + "%";
                      this.circle.style.left = x * 100 + "%";
                      this.circle.style.top = y * 100 + "%";
                      this.circle.style.width = radius * 200 + "%";
                      this.circle.style.height = radius * ar * 200 + "%";
                    },
                    dispatchChange() {
                      this.form?.dispatchEvent(new Event("change", { bubbles: true }));
                    },
                  };
                </script>
              </fieldset>
            <% :matching -> %>
              <fieldset class="mt-4 space-y-3">
                <div role="alert" class="alert alert-info alert-soft">
                  <.icon name="hero-information-circle" class="size-5 shrink-0" />
                  <span class="text-sm">
                    Die linke Spalte wird in dieser Reihenfolge angezeigt. Die Zuordnungen rechts werden gemischt — Teilnehmende ziehen sie an die passende Stelle.
                  </span>
                </div>

                <ul class="space-y-2 list-none p-0">
                  <.inputs_for :let={p} field={d[:pairs]}>
                    <li
                      id={"pair-#{p.index}"}
                      class="flex items-center gap-2 rounded-box bg-base-200 px-2 py-2"
                    >
                      <input type="hidden" name="question[data][pairs_sort][]" value={p.index} />

                      <input
                        type="text"
                        name={p[:left_text].name}
                        id={p[:left_text].id}
                        value={p[:left_text].value}
                        placeholder="Eintrag"
                        class="flex-1 min-w-0 bg-base-100 rounded-md border-none outline-none focus:ring-0 text-sm px-3 py-2"
                      />

                      <span class="text-base-content/40 shrink-0">↔</span>

                      <input
                        type="text"
                        name={p[:right_text].name}
                        id={p[:right_text].id}
                        value={p[:right_text].value}
                        placeholder="Zuordnung"
                        class="flex-1 min-w-0 bg-base-100 rounded-md border-none outline-none focus:ring-0 text-sm px-3 py-2"
                      />

                      <button
                        type="button"
                        name="question[data][pairs_drop][]"
                        value={p.index}
                        phx-click={JS.dispatch("change")}
                        class="text-base-content/40 hover:text-error px-2 text-lg leading-none shrink-0"
                        aria-label="Paar entfernen"
                      >
                        ×
                      </button>
                    </li>
                  </.inputs_for>
                </ul>

                <input type="hidden" name="question[data][pairs_drop][]" />

                <button
                  type="button"
                  name="question[data][pairs_sort][]"
                  value="new"
                  phx-click={JS.dispatch("change")}
                  class="w-full rounded-box border border-dashed border-base-300 px-3 py-3 text-sm text-base-content/70 hover:border-base-content/40 hover:text-base-content transition flex items-center justify-center gap-1"
                >
                  <span class="text-base">+</span> Paar hinzufügen
                </button>

                <p :if={pairs_error = data_field_error(@form, :pairs)} class="text-error text-sm">
                  {pairs_error}
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
    locked = Games.questions_locked?(game)

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:questions, questions)
     |> assign(:locked, locked)
     |> assign(:mode, if(locked, do: :view, else: :edit))
     |> assign(:selected_question, nil)
     |> assign(:question_type, nil)
     |> assign(:form, nil)
     |> assign(:save_status, nil)
     |> allow_upload(:pin_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
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
    |> assign(:save_status, nil)
  end

  defp apply_action(socket, :edit, params) do
    if Games.questions_locked?(socket.assigns.game) do
      socket
      |> put_flash(:error, @run_locked_message)
      |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")
    else
      authoring_action(socket, :edit, params)
    end
  end

  defp authoring_action(socket, :edit, %{"id" => id}) do
    question = Games.get_question!(socket.assigns.current_scope, id)
    changeset = Games.change_question(socket.assigns.current_scope, question)

    socket
    |> assign(:page_title, "Frage bearbeiten")
    |> assign(:selected_question, question)
    |> assign(:question_type, question.type)
    |> assign(:form, to_form(changeset))
    |> assign(:save_status, nil)
  end

  @impl true
  def handle_event("set_mode", %{"mode" => "view"}, socket) do
    {:noreply, assign(socket, :mode, :view)}
  end

  def handle_event("set_mode", %{"mode" => _}, socket) do
    {:noreply, assign(socket, :mode, if(socket.assigns.locked, do: :view, else: :edit))}
  end

  def handle_event("edit_question", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:mode, :edit)
     |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions/#{id}/edit")}
  end

  # Picking a type creates the question immediately and drops the user into its
  # edit form, where the full validation rules apply.
  def handle_event("create", %{"type" => type}, socket) do
    case parse_type(type) do
      nil ->
        {:noreply, put_flash(socket, :error, "Wähle einen Fragetyp.")}

      type ->
        case Games.create_question(socket.assigns.current_scope, socket.assigns.game, type) do
          {:ok, question} ->
            {:noreply,
             socket
             |> assign(:mode, :edit)
             |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions/#{question}/edit")}

          {:error, :run_locked} ->
            {:noreply,
             socket
             |> put_flash(:error, @run_locked_message)
             |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")}
        end
    end
  end

  def handle_event("validate", %{"question" => question_params}, socket) do
    {:noreply, autosave(socket, question_params)}
  end

  def handle_event("save", %{"question" => question_params}, socket) do
    save_question(socket, socket.assigns.live_action, question_params)
  end

  def handle_event("delete", _params, socket) do
    question = socket.assigns.selected_question

    case Games.delete_question(socket.assigns.current_scope, question) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Frage gelöscht")
         |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")}

      {:error, :run_locked} ->
        {:noreply,
         socket
         |> put_flash(:error, @run_locked_message)
         |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")}
    end
  end

  # Silently persists edits as they happen. On success nothing is surfaced (the
  # header save status stays clear); any failure is shown in the header via
  # :save_status. The form is rebuilt from the persisted record so embedded
  # answers keep ids in sync for the next change.
  #
  # A freshly uploaded background image is consumed *before* validating so the
  # new image_key is part of the changeset — otherwise a brand-new pin question
  # (which starts with no image) could never become valid and save.
  defp autosave(socket, question_params) do
    question_params = consume_pin_image(socket, question_params)

    changeset =
      Games.change_question(
        socket.assigns.current_scope,
        socket.assigns.selected_question,
        question_params
      )

    cond do
      not changeset.valid? ->
        socket
        |> assign(:form, to_form(changeset, action: :validate))
        |> assign(:save_status, "Nicht gespeichert – bitte Eingaben prüfen")

      true ->
        case Games.update_question(
               socket.assigns.current_scope,
               socket.assigns.selected_question,
               question_params
             ) do
          {:ok, question} ->
            form = to_form(Games.change_question(socket.assigns.current_scope, question))

            socket
            |> assign(:selected_question, question)
            |> assign(:form, form)
            |> assign(:save_status, nil)

          {:error, :run_locked} ->
            socket
            |> assign(:form, to_form(changeset, action: :validate))
            |> assign(:save_status, @run_locked_message)

          {:error, %Ecto.Changeset{} = changeset} ->
            socket
            |> assign(:form, to_form(changeset, action: :validate))
            |> assign(:save_status, "Speichern fehlgeschlagen")
        end
    end
  end

  defp save_question(socket, :edit, question_params) do
    question_params = consume_pin_image(socket, question_params)

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

      {:error, :run_locked} ->
        {:noreply,
         socket
         |> put_flash(:error, @run_locked_message)
         |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Persists a freshly uploaded background image via the storage adapter and
  # injects the returned key into the embedded pin params. A no-op when no new
  # file was staged (e.g. editing without re-uploading, or non-pin types).
  defp consume_pin_image(socket, question_params) do
    consumed =
      consume_uploaded_entries(socket, :pin_image, fn %{path: path}, entry ->
        Quiz.Storage.put(socket.assigns.current_scope, path,
          content_type: entry.client_type,
          filename: entry.client_name
        )
      end)

    case consumed do
      [key | _] -> put_pin_image_key(question_params, key)
      [] -> question_params
    end
  end

  defp put_pin_image_key(params, key) do
    data = Map.get(params, "data", %{})
    pin = data |> Map.get("pin", %{}) |> Map.put("image_key", key)
    Map.put(params, "data", Map.put(data, "pin", pin))
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

  defp blank?(value), do: value in [nil, ""] or String.trim(to_string(value)) == ""

  defp question_label(question),
    do: if(blank?(question.prompt), do: "Neue Frage", else: question.prompt)

  defp padded_count(questions), do: pad(length(questions))
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp selected?(nil, _question), do: false
  defp selected?(%{id: id}, %{id: id}), do: true
  defp selected?(_, _), do: false

  defp type_letter(:single_choice), do: "S"
  defp type_letter(:text_input), do: "T"
  defp type_letter(:sequence), do: "R"
  defp type_letter(:pin_on_image), do: "P"
  defp type_letter(:matching), do: "Z"
  defp type_letter(_), do: "?"

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

  defp items_summary(%{source: %Ecto.Changeset{} = cs}) do
    items =
      case Ecto.Changeset.get_field(cs, :data) do
        %{items: list} when is_list(list) -> list
        _ -> []
      end

    "#{length(items)} Einträge"
  end

  defp items_summary(_), do: "0 Einträge"

  defp pin_struct(%{source: %Ecto.Changeset{} = cs}) do
    case Ecto.Changeset.get_field(cs, :data) do
      %{pin: %Pin{} = pin} -> pin
      _ -> nil
    end
  end

  defp pin_struct(_), do: nil

  defp pin_image_key(form) do
    case pin_struct(form) do
      %Pin{image_key: key} when is_binary(key) and key != "" -> key
      _ -> nil
    end
  end

  @pin_defaults %{target_x: 0.5, target_y: 0.5, radius: 0.1, aspect_ratio: 1.0}

  defp pin_coord(form, field) do
    case pin_struct(form) do
      %Pin{} = pin -> Map.get(pin, field) || @pin_defaults[field]
      _ -> @pin_defaults[field]
    end
  end

  defp pin_summary(form) do
    case pin_struct(form) do
      %Pin{image_key: key} = pin when is_binary(key) and key != "" ->
        "Ziel gesetzt · Radius #{round((pin.radius || 0.1) * 100)}%"

      _ ->
        "Kein Bild"
    end
  end

  defp upload_error_to_string(:too_large), do: "Datei ist zu groß (max. 5 MB)."
  defp upload_error_to_string(:too_many_files), do: "Nur eine Datei erlaubt."
  defp upload_error_to_string(:not_accepted), do: "Nur JPG, PNG oder WEBP."
  defp upload_error_to_string(_), do: "Upload fehlgeschlagen."

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
