defmodule QuizWeb.QuestionLive.Index do
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.Question
  alias Quiz.Games.Question.NumberRange
  alias Quiz.Games.Question.Pin
  alias QuizWeb.AiWizard
  alias QuizWeb.GameLive.OpenRun
  alias QuizWeb.QuestionLive.{AnswerArea, SolutionArea}

  @valid_types ~w(single_choice multiple_choice text_input sequence pin_on_image matching number_range)

  @run_locked_message "Dieses Quiz ist abgeschlossen – Fragen können nicht mehr bearbeitet werden."

  @impl true
  # The last steps of «Quiz mit KI erstellen» (`QuizWeb.GameLive.Import`): the
  # freshly imported questions one at a time (`?frage=`), each to accept,
  # discard or adjust in the usual form, then the run settings (`?ablauf`).
  def render(%{live_action: :review} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl space-y-8">
        <AiWizard.steps current={if @review_step == :settings, do: 5, else: 4} />

        <section :if={@review_step == :settings} id="review-settings" class="space-y-8">
          <AiWizard.step_heading title="Wie soll dein Quiz ablaufen?">
            Beides kannst du später in den Einstellungen des Quiz ändern.
          </AiWizard.step_heading>

          <.form
            for={@settings_form}
            id="settings-form"
            phx-submit="save_settings"
            class="space-y-8 rounded-box border border-base-200 bg-base-100 p-6 shadow-sm sm:p-8"
          >
            <fieldset>
              <legend class="text-lg font-semibold">Wann zeigst du die Musterlösung?</legend>
              <div class="mt-3 grid gap-3 sm:grid-cols-2">
                <AiWizard.option_card
                  id="review-mode-per-question"
                  field={@settings_form[:review_mode]}
                  value="per_question"
                  icon="hero-chat-bubble-left-right"
                  title="Nach jeder Frage"
                  recommended
                >
                  Du löst jede Frage gleich auf und besprichst sie mit den Teams.
                </AiWizard.option_card>
                <AiWizard.option_card
                  id="review-mode-end"
                  field={@settings_form[:review_mode]}
                  value="end"
                  icon="hero-flag"
                  title="Am Ende des Quiz"
                >
                  Erst alle Fragen spielen, dann gemeinsam alle Lösungen durchgehen.
                </AiWizard.option_card>
              </div>
            </fieldset>

            <fieldset>
              <legend class="text-lg font-semibold">Statistik in der Besprechung</legend>
              <label class="mt-3 flex cursor-pointer items-center gap-4 rounded-box border-2 border-base-300 p-4 transition hover:border-primary/40 has-checked:border-primary has-checked:bg-primary/5">
                <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-secondary/40 text-primary">
                  <.icon name="hero-chart-bar" class="size-5" />
                </span>
                <span class="flex-1">
                  <span class="block text-lg font-semibold">Antwortverteilung zeigen</span>
                  <span class="block text-base text-base-content/80">
                    Bei der Auflösung sehen alle, wie die Teams geantwortet haben – ein guter
                    Einstieg in die Diskussion.
                  </span>
                </span>
                <input type="hidden" name={@settings_form[:show_statistics].name} value="false" />
                <input
                  id="show-statistics"
                  type="checkbox"
                  name={@settings_form[:show_statistics].name}
                  value="true"
                  checked={to_string(@settings_form[:show_statistics].value) == "true"}
                  class="toggle toggle-primary"
                />
              </label>
            </fieldset>

            <div class="flex items-center justify-between gap-3">
              <.link
                :if={@questions != []}
                patch={review_path(@game, length(@questions))}
                class="btn btn-ghost btn-lg"
              >
                <.icon name="hero-arrow-left" class="size-4" /> Zurück
              </.link>
              <button
                id="finish-review"
                type="submit"
                phx-disable-with="Wird gespeichert …"
                class="btn btn-primary btn-lg ml-auto"
              >
                Fertig – Quiz ansehen <.icon name="hero-arrow-right" class="size-4" />
              </button>
            </div>
          </.form>
        </section>

        <section :if={@review_step == :question} id="review-question-step" class="space-y-6">
          <div class="space-y-3">
            <div class="flex items-center justify-between gap-4 text-base">
              <p id="review-progress" class="font-semibold">
                Frage {@review_index} von {length(@questions)}
              </p>
              <p class="truncate text-base-content/70">{@game.title}</p>
            </div>
            <div class="h-2 overflow-hidden rounded-full bg-base-200" aria-hidden="true">
              <div
                class="h-full rounded-full bg-primary transition-all duration-500"
                style={"width: #{round(@review_index / length(@questions) * 100)}%"}
              >
              </div>
            </div>
          </div>

          <AiWizard.step_heading :if={!@review_editing} title="Passt diese Frage?">
            So sehen die Teams die Frage, darunter die Lösung. Nimm sie an, passe sie an oder
            verwirf sie.
          </AiWizard.step_heading>
          <AiWizard.step_heading :if={@review_editing} title="Frage anpassen">
            Deine Änderungen werden laufend gespeichert.
          </AiWizard.step_heading>

          <article
            :if={!@review_editing}
            id="review-question"
            class="space-y-5 rounded-box border border-base-300 bg-base-100 p-6 shadow-sm"
          >
            <% question = @selected_question %>
            <% image_missing = Question.image_missing?(question) %>
            <p class="font-mono text-xs uppercase tracking-wider text-base-content/70">
              Frage {pad(@review_index)} · {Keyword.fetch!(
                Quiz.Games.TextFormat.type_names(),
                question.type
              )}
            </p>
            <h2 class="text-xl font-bold">{question.prompt}</h2>
            <.rich_text html={question.description} />
            <.question_media question={question} class="max-w-md" />

            <div
              :if={image_missing}
              id="review-image-missing"
              class="flex flex-col gap-4 rounded-box border-2 border-dashed border-base-300 bg-base-200/60 p-5 sm:flex-row sm:items-center"
            >
              <span class="flex size-12 shrink-0 items-center justify-center rounded-xl bg-base-100 text-primary">
                <.icon name="hero-photo" class="size-6" />
              </span>
              <div class="min-w-0 flex-1 space-y-1 text-base">
                <p class="font-semibold">
                  {if question.type == :pin_on_image,
                    do: "Für diese Frage brauchst du ein Bild",
                    else: "Die KI schlägt ein Bild vor (optional)"}
                </p>
                <p :if={present?(question.image_hint)} class="text-base-content/80">
                  {question.image_hint}
                </p>
                <p
                  :if={question.type == :pin_on_image and present?(question.pin_hint)}
                  class="text-base-content/80"
                >
                  Die Teams tippen auf: {question.pin_hint}
                </p>
              </div>
              <button
                id="review-upload-image"
                type="button"
                phx-click="review_edit"
                class="btn btn-primary shrink-0"
              >
                <.icon name="hero-arrow-up-tray" class="size-4" /> Bild hochladen
              </button>
            </div>

            <AnswerArea.answer_area
              :if={!(question.type == :pin_on_image and image_missing)}
              question={AnswerArea.prepare_question(question)}
            />

            <div
              :if={!(question.type == :pin_on_image and image_missing)}
              id="review-solution"
              class="space-y-4 border-t border-base-200 pt-5"
            >
              <p class="inline-flex items-center gap-1.5 rounded-full bg-success/15 px-3 py-1 text-sm font-semibold text-base-content">
                <.icon name="hero-eye-slash" class="size-4 text-success" />
                Lösung – sehen die Teams erst bei der Auflösung
              </p>
              <SolutionArea.solution_area question={question} />
              <SolutionArea.solution_explanation question={question} />
            </div>

            <%!-- A missing pin image is asked for above already. --%>
            <% missing =
              if image_missing,
                do: Question.missing_requirements(question) -- ["ein Bild mit markiertem Ziel"],
                else: Question.missing_requirements(question) %>
            <div
              :if={missing != []}
              id="review-missing"
              class="flex items-start gap-3 rounded-box border border-warning/50 bg-warning/10 p-4 text-base"
            >
              <.icon name="hero-exclamation-triangle" class="mt-0.5 size-5 shrink-0 text-warning" />
              <p>
                <span class="font-semibold">Noch nicht spielbar – es fehlt:</span>
                {Enum.join(missing, ", ")}. Über «Anpassen» kannst du das ergänzen.
              </p>
            </div>
          </article>

          <div :if={@review_editing} id="review-editing" class="space-y-4">
            <p
              :if={@save_status}
              class="flex items-center gap-1 text-base text-error"
              role="alert"
            >
              <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
              {@save_status}
            </p>
            <.question_form
              form={@form}
              game={@game}
              live_action={@live_action}
              question_type={@question_type}
              selected_question={@selected_question}
              uploads={@uploads}
              media_tab={@media_tab}
              solution_tab={@solution_tab}
            />
          </div>

          <div :if={@review_editing} class="flex justify-end">
            <button
              id="review-done"
              type="button"
              phx-click="review_done"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-check" class="size-5" /> Fertig angepasst
            </button>
          </div>

          <div
            :if={!@review_editing}
            class="flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between"
          >
            <div class="flex items-center gap-2">
              <.link
                :if={@review_index > 1}
                id="review-previous"
                patch={review_path(@game, @review_index - 1)}
                class="btn btn-ghost btn-lg"
                aria-label="Vorherige Frage"
              >
                <.icon name="hero-arrow-left" class="size-4" />
              </.link>
              <button
                id="review-discard"
                type="button"
                phx-click="review_discard"
                class="btn btn-ghost btn-lg text-error"
              >
                <.icon name="hero-trash" class="size-5" /> Verwerfen
              </button>
            </div>
            <div class="flex gap-3">
              <button
                id="review-edit"
                type="button"
                phx-click="review_edit"
                class="btn btn-soft btn-lg flex-1 sm:flex-none"
              >
                <.icon name="hero-pencil-square" class="size-5" /> Anpassen
              </button>
              <.link
                id="review-accept"
                patch={review_path(@game, @review_index + 1)}
                class="btn btn-primary btn-lg flex-1 sm:flex-none"
              >
                Annehmen <.icon name="hero-arrow-right" class="size-4" />
              </.link>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

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
            <div class="flex items-center gap-2">
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
                    <button
                      id="delete-question"
                      type="button"
                      class="text-error"
                      onclick={open_modal("delete_question_modal", close_popover: "question-actions")}
                    >
                      <.icon name="hero-trash" class="size-5" /> Frage löschen
                    </button>
                  </li>
                </ul>
                <.confirm_modal
                  id="delete_question_modal"
                  title="Frage löschen?"
                  confirm="Frage löschen"
                  event="delete"
                >
                  «{question_label(@selected_question)}» wird endgültig gelöscht. Das lässt sich nicht
                  rückgängig machen.
                </.confirm_modal>
              </div>
              <OpenRun.run_button game={@game} has_questions={@questions != []} />
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
                  phx-value-mode="view"
                  class={[
                    "flex-1 inline-flex items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition",
                    @mode == :view && "bg-base-100 shadow-sm text-base-content",
                    @mode != :view && "text-base-content/60 hover:text-base-content"
                  ]}
                >
                  <.icon name="hero-eye" class="size-4" /> Ansehen
                </button>
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
                    :if={@mode == :edit}
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
                      <span
                        :if={incomplete?(question)}
                        class="tooltip tooltip-left ml-auto shrink-0 text-warning"
                        data-tip="Unvollständig – kann noch nicht gespielt werden"
                        aria-label="Unvollständig"
                      >
                        <.icon name="hero-exclamation-triangle" class="size-4" />
                      </span>
                    </div>
                  </.link>
                  <%!-- In «Ansehen» every question is on the page: jump to it. --%>
                  <a
                    :if={@mode == :view}
                    href={"#view-question-#{question.id}"}
                    class="block rounded-md px-3 py-2 border border-transparent transition hover:bg-base-200/60"
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
                  </a>
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

          <section class="flex-1 min-w-0 h-full overflow-y-auto scroll-smooth">
            <OpenRun.confirm
              game={@game}
              questions={@questions}
              incomplete={@incomplete_questions}
              class="mb-6"
            />
            <div :if={@mode == :edit}>
              <.type_picker :if={@live_action == :index} game={@game} insert_at={@insert_at} />
              <.question_form
                :if={@live_action == :edit}
                form={@form}
                game={@game}
                live_action={@live_action}
                question_type={@question_type}
                selected_question={@selected_question}
                uploads={@uploads}
                media_tab={@media_tab}
                solution_tab={@solution_tab}
              />
            </div>

            <div :if={@mode == :view} class="space-y-3 max-w-2xl">
              <div
                :if={@questions == []}
                class="rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
              >
                Noch keine Fragen in diesem Quiz.
              </div>
              <.insert_question_button :if={!@locked} at={0} />
              <%= for {q, idx} <- Enum.with_index(@questions) do %>
                <article
                  id={"view-question-#{q.id}"}
                  class="group relative scroll-mt-4 rounded-box border border-base-300 bg-base-100 p-6 space-y-4"
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
                  <.question_media question={q} class="max-w-md" />
                  <AnswerArea.answer_area question={AnswerArea.prepare_question(q)} />
                </article>
                <.insert_question_button :if={!@locked} at={idx + 1} />
              <% end %>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :at, :integer, required: true, doc: "0-based index the new question goes to"

  defp insert_question_button(assigns) do
    ~H"""
    <button
      id={"insert-question-#{@at}"}
      type="button"
      phx-click="add_question_at"
      phx-value-at={@at}
      class="flex w-full cursor-pointer items-center justify-center gap-2 rounded-box border-2 border-dashed border-base-300 py-2.5 text-sm font-medium text-base-content/50 transition hover:border-primary/40 hover:bg-base-200/50 hover:text-primary"
    >
      <.icon name="hero-plus" class="size-4" /> Frage hinzufügen
    </button>
    """
  end

  attr :game, :map, required: true
  attr :insert_at, :integer, default: nil

  defp type_picker(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl py-12 text-center">
      <p class="text-xs font-mono uppercase tracking-wider text-base-content/60">
        {if @insert_at, do: "Neue Frage an Position #{@insert_at + 1}", else: "Starte mit einer Frage"}
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
          phx-value-type="multiple_choice"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            M
          </div>
          <h2 class="mt-4 text-lg font-bold">Multiple-Choice</h2>
          <p class="text-sm text-base-content/60">Mehrere richtige Antworten</p>
          <div class="mt-4 space-y-2">
            <div class="flex items-center gap-2">
              <span class="inline-block size-3 rounded-sm bg-base-content"></span>
              <span class="block h-2 w-2/3 rounded bg-base-200"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="inline-block size-3 rounded-sm border border-base-300"></span>
              <span class="block h-2 w-1/2 rounded bg-base-200"></span>
            </div>
            <div class="flex items-center gap-2">
              <span class="inline-block size-3 rounded-sm bg-base-content"></span>
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

        <button
          type="button"
          phx-click="create"
          phx-value-type="number_range"
          class="group w-full text-left rounded-box border border-base-300 bg-base-100 p-6 hover:border-base-content/40 hover:shadow-sm transition"
        >
          <div class="flex items-center justify-center size-9 rounded-md bg-success/20 text-success font-mono font-bold">
            N
          </div>
          <h2 class="mt-4 text-lg font-bold">Zahlenschätzung</h2>
          <p class="text-sm text-base-content/60">Zahl in einem Bereich schätzen</p>
          <div class="mt-6 space-y-2">
            <div class="relative h-1.5 rounded-full bg-base-200">
              <span class="absolute left-1/3 top-1/2 h-3 w-0.5 -translate-y-1/2 rounded bg-base-content/30">
              </span>
              <span class="absolute left-1/2 top-1/2 size-3 -translate-x-1/2 -translate-y-1/2 rounded-full bg-success">
              </span>
              <span class="absolute right-1/4 top-1/2 size-2.5 -translate-y-1/2 rounded-full bg-success/40">
              </span>
            </div>
            <div class="flex justify-between font-mono text-[10px] text-base-content/50">
              <span>min</span>
              <span>max</span>
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
  attr :media_tab, :atom, required: true
  attr :solution_tab, :atom, required: true

  defp question_form(assigns) do
    assigns =
      assign(
        assigns,
        :missing,
        Quiz.Games.Question.missing_requirements(assigns.selected_question)
      )

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

        <div
          :if={@missing != []}
          class="flex items-start gap-3 rounded-box border border-warning/40 bg-warning/10 p-4 text-sm"
        >
          <.icon name="hero-exclamation-triangle" class="mt-0.5 size-5 shrink-0 text-warning" />
          <div>
            <p class="font-semibold text-base-content">
              Noch nicht spielbar – es fehlt:
            </p>
            <ul class="mt-1 list-disc list-inside space-y-0.5 text-base-content/70">
              <li :for={item <- @missing}>{item}</li>
            </ul>
          </div>
        </div>

        <.input field={@form[:prompt]} type="textarea" label="Fragetext" />

        <% media_key = media_image_key(@form) %>
        <% video_key = media_video_key(@form) %>
        <div class="space-y-3">
          <div class="flex items-center justify-between gap-4">
            <span class="block text-sm font-semibold">
              Bild oder Video <span class="font-normal text-base-content/50">(optional)</span>
            </span>
            <div class="join" role="tablist" aria-label="Medientyp">
              <button
                type="button"
                id="media-tab-image"
                phx-click="media_tab"
                phx-value-tab="image"
                class={[
                  "btn btn-sm join-item",
                  (@media_tab == :image && "btn-primary") || "btn-soft"
                ]}
              >
                <.icon name="hero-photo" class="size-4" /> Bild
              </button>
              <button
                type="button"
                id="media-tab-video"
                phx-click="media_tab"
                phx-value-tab="video"
                class={[
                  "btn btn-sm join-item",
                  (@media_tab == :video && "btn-primary") || "btn-soft"
                ]}
              >
                <.icon name="hero-play" class="size-4" /> Video
              </button>
            </div>
          </div>

          <.author_hint
            :if={
              @question_type != :pin_on_image and present?(@selected_question.image_hint) and
                is_nil(media_key) and is_nil(video_key)
            }
            id="image-hint"
            icon="hero-photo"
            title="Gesuchtes Bild"
            text={@selected_question.image_hint}
            search
          />

          <div :if={@media_tab == :image} class="space-y-3">
            <div
              class="rounded-box border border-dashed border-base-300 p-4"
              phx-drop-target={@uploads.media_image.ref}
            >
              <div class="space-y-2">
                <div class="text-sm text-base-content/70">
                  <p class="font-semibold">
                    {if media_key, do: "Bild ersetzen", else: "Bild hochladen"}
                  </p>
                  <p class="text-xs text-base-content/50">
                    JPG, PNG oder WEBP · max. 5 MB. Ziehe eine Datei hierher oder wähle sie aus.
                  </p>
                </div>
                <.live_file_input upload={@uploads.media_image} class="file-input w-full" />
              </div>

              <p :for={err <- upload_errors(@uploads.media_image)} class="mt-2 text-error text-sm">
                {upload_error_to_string(err)}
              </p>
              <p
                :for={entry <- @uploads.media_image.entries}
                :if={err = List.first(upload_errors(@uploads.media_image, entry))}
                class="mt-2 text-error text-sm"
              >
                {upload_error_to_string(err)}
              </p>
            </div>

            <%!-- Server-owned: written by the upload progress callback, never by
                  the client; round-trips the persisted key through autosaves. --%>
            <input type="hidden" name="question[media_image_key]" value={media_key} />

            <div :if={media_key} class="space-y-2">
              <img
                src={Quiz.Storage.url(media_key)}
                alt="Bild zur Frage"
                class="max-h-48 rounded-box object-contain"
              />
              <button
                type="button"
                id="remove-media-image"
                phx-click="remove_media_image"
                class="btn btn-ghost btn-sm text-error"
              >
                <.icon name="hero-trash" class="size-4" /> Bild entfernen
              </button>
            </div>
          </div>

          <div :if={@media_tab == :video} class="space-y-3">
            <div
              class="rounded-box border border-dashed border-base-300 p-4"
              phx-drop-target={@uploads.media_video.ref}
            >
              <div class="space-y-2">
                <div class="text-sm text-base-content/70">
                  <p class="font-semibold">
                    {if video_key, do: "Video ersetzen", else: "Video hochladen"}
                  </p>
                  <p class="text-xs text-base-content/50">
                    MP4 oder WEBM (H.264) · max. 50 MB. Ziehe eine Datei hierher oder wähle sie aus.
                  </p>
                </div>
                <.live_file_input upload={@uploads.media_video} class="file-input w-full" />
              </div>

              <div
                :for={entry <- @uploads.media_video.entries}
                :if={entry.progress > 0 and entry.progress < 100}
                class="mt-3"
              >
                <progress class="progress progress-primary w-full" value={entry.progress} max="100">
                </progress>
              </div>

              <p :for={err <- upload_errors(@uploads.media_video)} class="mt-2 text-error text-sm">
                {video_upload_error_to_string(err)}
              </p>
              <p
                :for={entry <- @uploads.media_video.entries}
                :if={err = List.first(upload_errors(@uploads.media_video, entry))}
                class="mt-2 text-error text-sm"
              >
                {video_upload_error_to_string(err)}
              </p>
            </div>

            <%!-- Server-owned: written by the upload progress callback, never by
                  the client; round-trips the persisted key through autosaves. --%>
            <input type="hidden" name="question[media_video_key]" value={video_key} />

            <div :if={video_key} class="space-y-2">
              <video
                src={Quiz.Storage.url(video_key)}
                controls
                preload="metadata"
                playsinline
                class="max-h-48 max-w-md rounded-box bg-black"
              >
              </video>
              <button
                type="button"
                id="remove-media-video"
                phx-click="remove_media_video"
                class="btn btn-ghost btn-sm text-error"
              >
                <.icon name="hero-trash" class="size-4" /> Video entfernen
              </button>
            </div>
          </div>
        </div>

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
                  // Dispatch on the input, not the form: LiveView finds the form
                  // via event.target.form, so a form-targeted event is ignored.
                  this.input.dispatchEvent(new Event("input", { bubbles: true }));
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

                <ul id="choices-list" phx-hook=".SingleCorrect" class="space-y-2 list-none p-0">
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
                        {choice_letter_text(c.index)}
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

                <script :type={Phoenix.LiveView.ColocatedHook} name=".SingleCorrect">
                  export default {
                    mounted() {
                      // A single-choice question has exactly one correct answer,
                      // but each row carries its own checkbox. Without this, ticking
                      // a second option leaves two ticked and the form drops into a
                      // validation error. Enforce single-select on the client by
                      // unticking the others *before* the change bubbles to the
                      // form's phx-change, so the autosave already sees one correct.
                      this.el.addEventListener("change", (e) => {
                        const cb = e.target;
                        if (
                          cb.type === "checkbox" &&
                          cb.name.endsWith("[correct]") &&
                          cb.checked
                        ) {
                          this.el
                            .querySelectorAll('input[type="checkbox"][name$="[correct]"]')
                            .forEach((other) => {
                              if (other !== cb) other.checked = false;
                            });
                        }
                      });
                    },
                  };
                </script>
              </fieldset>
            <% :multiple_choice -> %>
              <fieldset class="mt-8 space-y-3">
                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Antwortoptionen · Wähle alle richtigen aus</span>
                  <span>{choices_summary(@form)}</span>
                </div>

                <ul id="choices-list" class="space-y-2 list-none p-0">
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
                        {choice_letter_text(c.index)}
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
                        <span class="size-5 rounded border-2 border-base-300 grid place-items-center transition peer-checked:bg-success peer-checked:border-success">
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
                        // Fire phx-change on a real input (the reordered sort
                        // fields), not the form: LiveView resolves the form via
                        // event.target.form, so an event whose target is the form
                        // itself is ignored — the reorder would never autosave.
                        const sortInput = el.querySelector('input[name="question[data][items_sort][]"]');
                        if (sortInput) sortInput.dispatchEvent(new Event("input", { bubbles: true }));
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
              <% qid = @selected_question.id %>
              <% has_image = !is_nil(entry) or not is_nil(image_key) %>
              <fieldset
                id={"pin-fieldset-#{qid}"}
                phx-hook=".PinEditor"
                data-image-url={image_key && Quiz.Storage.url(image_key)}
                data-target-x={pin_coord(@form, :target_x)}
                data-target-y={pin_coord(@form, :target_y)}
                data-radius={pin_coord(@form, :radius)}
                data-aspect-ratio={pin_coord(@form, :aspect_ratio)}
                class="mt-8 space-y-4"
              >
                <div class="flex items-center justify-between text-xs font-mono uppercase tracking-wider text-base-content/60">
                  <span>Hintergrundbild · Setze das Ziel</span>
                  <span>{pin_summary(@form)}</span>
                </div>

                <.author_hint
                  :if={!has_image and present?(@selected_question.image_hint)}
                  id="pin-image-hint"
                  icon="hero-photo"
                  title="Gesuchtes Bild"
                  text={@selected_question.image_hint}
                  search
                />
                <.author_hint
                  :if={present?(@selected_question.pin_hint)}
                  id="pin-hint"
                  icon="hero-map-pin"
                  title="Hier gehört der Pin hin"
                  text={@selected_question.pin_hint}
                />

                <div
                  class="rounded-box border border-dashed border-base-300 p-4"
                  phx-drop-target={@uploads.pin_image.ref}
                >
                  <div class="space-y-2">
                    <div class="text-sm text-base-content/70">
                      <p class="font-semibold">
                        {if has_image, do: "Bild ersetzen", else: "Bild hochladen"}
                      </p>
                      <p class="text-xs text-base-content/50">
                        JPG, PNG oder WEBP · max. 5 MB. Ziehe eine Datei hierher oder wähle sie aus.
                      </p>
                    </div>
                    <.live_file_input upload={@uploads.pin_image} class="file-input w-full" />
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

                <%!-- Server-owned: written by the upload progress callback, never
                      by the client. Lives outside the ignored containers below so
                      it always reflects the persisted key. --%>
                <input
                  type="hidden"
                  name="question[data][pin][image_key]"
                  value={image_key}
                />

                <%!-- The editor box and coordinate inputs are client-owned: the
                      PinEditor hook is the single source of truth for the target,
                      radius and aspect ratio. They sit in phx-update="ignore"
                      containers (keyed by question id) so server re-renders from
                      autosave never stomp values the user just set. --%>
                <div data-editor-wrap class={["space-y-3", !has_image && "hidden"]}>
                  <p class="text-xs text-base-content/60">
                    Klicke auf das Bild, um das Ziel zu setzen. Mit dem Regler unten passt du
                    den Toleranzradius an.
                  </p>

                  <div
                    id={"pin-editor-box-#{qid}"}
                    phx-update="ignore"
                    data-editor-box
                    class="relative w-full max-w-md overflow-hidden rounded-box bg-base-200 cursor-crosshair select-none"
                    style={"aspect-ratio: #{pin_coord(@form, :aspect_ratio)};"}
                  >
                    <img
                      data-bg
                      src={image_key && Quiz.Storage.url(image_key)}
                      class="absolute inset-0 w-full h-full object-cover pointer-events-none"
                      alt="Hintergrundbild"
                    />
                    <div data-layer class="absolute inset-0 pointer-events-none"></div>
                  </div>

                  <div id={"pin-controls-#{qid}"} phx-update="ignore">
                    <label class="flex items-center gap-3 text-sm max-w-md">
                      <span class="shrink-0 text-base-content/70">Radius</span>
                      <input
                        type="range"
                        name="question[data][pin][radius]"
                        min="0.02"
                        max="0.5"
                        step="0.01"
                        value={pin_coord(@form, :radius)}
                        data-radius-input
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
                </div>

                <p :if={pin_error = data_field_error(@form, :pin)} class="text-error text-sm">
                  {pin_error}
                </p>

                <script :type={Phoenix.LiveView.ColocatedHook} name=".PinEditor">
                  export default {
                    mounted() {
                      this.form = this.el.closest("form");
                      this.wrap = this.el.querySelector("[data-editor-wrap]");
                      this.box = this.el.querySelector("[data-editor-box]");
                      this.img = this.el.querySelector("[data-bg]");
                      this.layer = this.el.querySelector("[data-layer]");
                      this.fileInput = this.el.querySelector('input[type="file"]');
                      this.radiusEl = this.input("radius");

                      this.shownUrl = null; // stored URL currently displayed
                      this.objectUrl = null; // local blob URL, if any
                      this.awaitingUpload = false; // a freshly picked file is streaming up
                      this.preReplaceUrl = null; // stored URL shown when that file was picked

                      this.circle = document.createElement("div");
                      this.circle.className =
                        "absolute rounded-full bg-error/20 border-2 border-error/60 -translate-x-1/2 -translate-y-1/2";
                      this.marker = document.createElement("div");
                      this.marker.className =
                        "absolute size-3 rounded-full bg-error ring-2 ring-white shadow -translate-x-1/2 -translate-y-1/2";
                      this.layer.appendChild(this.circle);
                      this.layer.appendChild(this.marker);

                      // Show the picked file instantly from a local object URL —
                      // this is independent of the upload round-trip, so the
                      // preview never blanks out while the file streams up.
                      this.onFile = () => {
                        const file = this.fileInput?.files?.[0];
                        if (!file) return;
                        if (this.objectUrl) URL.revokeObjectURL(this.objectUrl);
                        this.objectUrl = URL.createObjectURL(file);
                        // Remember which stored image is being replaced so the
                        // local preview is not reverted to it by a validate that
                        // fires while the new file is still streaming up.
                        this.preReplaceUrl = this.shownUrl;
                        this.awaitingUpload = true;
                        this.shownUrl = null;
                        this.img.src = this.objectUrl;
                        this.img.onload = () => this.captureAspect();
                        this.showBox();
                      };
                      if (this.fileInput) this.fileInput.addEventListener("change", this.onFile);

                      this.onClick = (e) => {
                        if (!this.img.getAttribute("src")) return;
                        const r = this.box.getBoundingClientRect();
                        const x = Math.min(Math.max((e.clientX - r.left) / r.width, 0), 1);
                        const y = Math.min(Math.max((e.clientY - r.top) / r.height, 0), 1);
                        this.setInput("target_x", x);
                        this.setInput("target_y", y);
                        this.renderMarker();
                        this.dispatchChange();
                      };
                      this.box.addEventListener("click", this.onClick);

                      this.onRadius = () => this.renderMarker();
                      if (this.radiusEl) this.radiusEl.addEventListener("input", this.onRadius);

                      this.syncStoredImage();
                      this.renderMarker();
                    },

                    updated() {
                      // After an upload is persisted, the stored URL arrives on a
                      // re-render; swap to it without flashing (see swapTo).
                      this.syncStoredImage();
                      this.renderMarker();
                    },

                    destroyed() {
                      if (this.fileInput) this.fileInput.removeEventListener("change", this.onFile);
                      this.box?.removeEventListener("click", this.onClick);
                      if (this.radiusEl) this.radiusEl.removeEventListener("input", this.onRadius);
                      if (this.objectUrl) URL.revokeObjectURL(this.objectUrl);
                    },

                    syncStoredImage() {
                      const url = this.el.dataset.imageUrl;
                      if (!url) return;
                      this.showBox();
                      this.swapTo(url);
                    },

                    // Preload the stored image, then swap the visible src only
                    // once it has decoded. The local preview (or the previously
                    // shown image) stays put until then, so there is no flash.
                    swapTo(url) {
                      // While a freshly picked file is uploading, keep showing
                      // its local preview — don't revert to the image it replaces.
                      if (this.awaitingUpload && url === this.preReplaceUrl) return;
                      if (this.shownUrl === url) return;
                      if (this.img.getAttribute("src") === url) {
                        this.shownUrl = url;
                        this.awaitingUpload = false;
                        this.captureAspect();
                        return;
                      }
                      const pre = new Image();
                      pre.onload = () => {
                        this.shownUrl = url;
                        this.awaitingUpload = false;
                        this.img.src = url;
                        this.applyAspect(pre.naturalWidth / pre.naturalHeight);
                        if (this.objectUrl) {
                          URL.revokeObjectURL(this.objectUrl);
                          this.objectUrl = null;
                        }
                      };
                      pre.src = url;
                    },

                    captureAspect() {
                      if (this.img.naturalWidth && this.img.naturalHeight) {
                        this.applyAspect(this.img.naturalWidth / this.img.naturalHeight);
                      }
                    },

                    // Mirror the image's natural aspect ratio into the box and the
                    // hidden input; persist it (via a change) only when it really
                    // differs, so scoring matches what the author sees.
                    applyAspect(ar) {
                      if (!Number.isFinite(ar) || ar <= 0) return;
                      if (this.box) this.box.style.aspectRatio = ar;
                      const cur = parseFloat(this.input("aspect_ratio")?.value);
                      if (!Number.isFinite(cur) || Math.abs(cur - ar) > 0.001) {
                        this.setInput("aspect_ratio", ar);
                        this.dispatchChange();
                      }
                      this.renderMarker();
                    },

                    showBox() {
                      if (this.wrap) this.wrap.classList.remove("hidden");
                    },

                    input(field) {
                      return this.form?.querySelector(`[name="question[data][pin][${field}]"]`);
                    },
                    setInput(field, value) {
                      const el = this.input(field);
                      if (el) el.value = value;
                    },
                    num(field, fallback) {
                      const el = this.input(field);
                      const v = el ? parseFloat(el.value) : NaN;
                      return Number.isFinite(v) ? v : fallback;
                    },

                    renderMarker() {
                      const x = this.num("target_x", parseFloat(this.el.dataset.targetX) || 0.5);
                      const y = this.num("target_y", parseFloat(this.el.dataset.targetY) || 0.5);
                      const radius = this.radiusEl
                        ? parseFloat(this.radiusEl.value) || 0.1
                        : parseFloat(this.el.dataset.radius) || 0.1;
                      const ar = this.num("aspect_ratio", parseFloat(this.el.dataset.aspectRatio) || 1) || 1;
                      this.marker.style.left = x * 100 + "%";
                      this.marker.style.top = y * 100 + "%";
                      this.circle.style.left = x * 100 + "%";
                      this.circle.style.top = y * 100 + "%";
                      this.circle.style.width = radius * 200 + "%";
                      this.circle.style.height = radius * ar * 200 + "%";
                    },

                    // Trigger the form's phx-change autosave. The event MUST be
                    // dispatched on a real input, not the form: LiveView locates
                    // the form via event.target.form, so an event whose target is
                    // the form itself is silently ignored — which is why a placed
                    // target only saved when some other input event happened to
                    // carry it along.
                    dispatchChange() {
                      const el = this.input("target_x");
                      if (el) el.dispatchEvent(new Event("input", { bubbles: true }));
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
            <% :number_range -> %>
              <fieldset class="mt-4 space-y-3">
                <div role="alert" class="alert alert-info alert-soft">
                  <.icon name="hero-information-circle" class="size-5 shrink-0" />
                  <span class="text-sm">
                    Teilnehmende geben eine Zahl ein. Alles zwischen Lösung minus und plus Toleranz zählt als richtig.
                  </span>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <label class="space-y-1">
                    <span class="text-xs font-mono uppercase tracking-wider text-base-content/60">
                      Minimum
                    </span>
                    <input
                      type="number"
                      step="1"
                      name="question[data][number_range][min]"
                      value={nr_field(@form, :min)}
                      placeholder="z. B. 10"
                      class="w-full rounded-box bg-base-200 border-none outline-none focus:ring-2 focus:ring-primary text-sm px-3 py-2"
                    />
                  </label>

                  <label class="space-y-1">
                    <span class="text-xs font-mono uppercase tracking-wider text-base-content/60">
                      Maximum
                    </span>
                    <input
                      type="number"
                      step="1"
                      name="question[data][number_range][max]"
                      value={nr_field(@form, :max)}
                      placeholder="z. B. 700"
                      class="w-full rounded-box bg-base-200 border-none outline-none focus:ring-2 focus:ring-primary text-sm px-3 py-2"
                    />
                  </label>

                  <label class="space-y-1">
                    <span class="text-xs font-mono uppercase tracking-wider text-base-content/60">
                      Lösung
                    </span>
                    <input
                      type="number"
                      step="1"
                      name="question[data][number_range][solution]"
                      value={nr_field(@form, :solution)}
                      placeholder="z. B. 350"
                      class="w-full rounded-box bg-base-200 border-none outline-none focus:ring-2 focus:ring-primary text-sm px-3 py-2"
                    />
                  </label>

                  <label class="space-y-1">
                    <span class="text-xs font-mono uppercase tracking-wider text-base-content/60">
                      Toleranz (±)
                    </span>
                    <input
                      type="number"
                      step="1"
                      min="0"
                      name="question[data][number_range][tolerance]"
                      value={nr_field(@form, :tolerance)}
                      placeholder="z. B. 20"
                      class="w-full rounded-box bg-base-200 border-none outline-none focus:ring-2 focus:ring-primary text-sm px-3 py-2"
                    />
                  </label>
                </div>

                <p :if={band = number_range_band(@form)} class="text-xs text-base-content/50">
                  Akzeptierter Bereich: {band}
                </p>

                <p
                  :if={nr_error = data_field_error(@form, :number_range)}
                  class="text-error text-sm"
                >
                  {nr_error}
                </p>
              </fieldset>
          <% end %>
        </.inputs_for>

        <% solution_key = solution_image_key(@form) %>
        <% solution_video = solution_video_key(@form) %>
        <div class="mt-8 space-y-3 border-t border-base-300 pt-6">
          <div>
            <span class="block text-sm font-semibold">
              Lösungserklärung <span class="font-normal text-base-content/50">(optional)</span>
            </span>
            <p class="text-xs text-base-content/50">
              Text und/oder Bild bzw. Video – wird bei der Lösungsbesprechung zusammen mit der
              Musterlösung gezeigt.
            </p>
          </div>

          <.input
            field={@form[:solution_text]}
            type="textarea"
            placeholder="z. B. warum diese Antwort richtig ist"
          />

          <div class="flex items-center justify-between gap-4">
            <span class="text-xs font-mono uppercase tracking-wider text-base-content/60">
              Bild oder Video
            </span>
            <div class="join" role="tablist" aria-label="Medientyp der Lösungserklärung">
              <button
                type="button"
                id="solution-tab-image"
                phx-click="solution_tab"
                phx-value-tab="image"
                class={[
                  "btn btn-sm join-item",
                  (@solution_tab == :image && "btn-primary") || "btn-soft"
                ]}
              >
                <.icon name="hero-photo" class="size-4" /> Bild
              </button>
              <button
                type="button"
                id="solution-tab-video"
                phx-click="solution_tab"
                phx-value-tab="video"
                class={[
                  "btn btn-sm join-item",
                  (@solution_tab == :video && "btn-primary") || "btn-soft"
                ]}
              >
                <.icon name="hero-play" class="size-4" /> Video
              </button>
            </div>
          </div>

          <div :if={@solution_tab == :image} class="space-y-3">
            <div
              class="rounded-box border border-dashed border-base-300 p-4"
              phx-drop-target={@uploads.solution_image.ref}
            >
              <div class="space-y-2">
                <div class="text-sm text-base-content/70">
                  <p class="font-semibold">
                    {if solution_key, do: "Bild ersetzen", else: "Bild hochladen"}
                  </p>
                  <p class="text-xs text-base-content/50">
                    JPG, PNG oder WEBP · max. 5 MB. Ziehe eine Datei hierher oder wähle sie aus.
                  </p>
                </div>
                <.live_file_input upload={@uploads.solution_image} class="file-input w-full" />
              </div>

              <p
                :for={err <- upload_errors(@uploads.solution_image)}
                class="mt-2 text-error text-sm"
              >
                {upload_error_to_string(err)}
              </p>
              <p
                :for={entry <- @uploads.solution_image.entries}
                :if={err = List.first(upload_errors(@uploads.solution_image, entry))}
                class="mt-2 text-error text-sm"
              >
                {upload_error_to_string(err)}
              </p>
            </div>

            <%!-- Server-owned: written by the upload progress callback, never by
                  the client; round-trips the persisted key through autosaves. --%>
            <input type="hidden" name="question[solution_image_key]" value={solution_key} />

            <div :if={solution_key} class="space-y-2">
              <img
                src={Quiz.Storage.url(solution_key)}
                alt="Bild zur Lösungserklärung"
                class="max-h-48 rounded-box object-contain"
              />
              <button
                type="button"
                id="remove-solution-image"
                phx-click="remove_solution_image"
                class="btn btn-ghost btn-sm text-error"
              >
                <.icon name="hero-trash" class="size-4" /> Bild entfernen
              </button>
            </div>
          </div>

          <div :if={@solution_tab == :video} class="space-y-3">
            <div
              class="rounded-box border border-dashed border-base-300 p-4"
              phx-drop-target={@uploads.solution_video.ref}
            >
              <div class="space-y-2">
                <div class="text-sm text-base-content/70">
                  <p class="font-semibold">
                    {if solution_video, do: "Video ersetzen", else: "Video hochladen"}
                  </p>
                  <p class="text-xs text-base-content/50">
                    MP4 oder WEBM (H.264) · max. 50 MB. Ziehe eine Datei hierher oder wähle sie aus.
                  </p>
                </div>
                <.live_file_input upload={@uploads.solution_video} class="file-input w-full" />
              </div>

              <div
                :for={entry <- @uploads.solution_video.entries}
                :if={entry.progress > 0 and entry.progress < 100}
                class="mt-3"
              >
                <progress class="progress progress-primary w-full" value={entry.progress} max="100">
                </progress>
              </div>

              <p
                :for={err <- upload_errors(@uploads.solution_video)}
                class="mt-2 text-error text-sm"
              >
                {video_upload_error_to_string(err)}
              </p>
              <p
                :for={entry <- @uploads.solution_video.entries}
                :if={err = List.first(upload_errors(@uploads.solution_video, entry))}
                class="mt-2 text-error text-sm"
              >
                {video_upload_error_to_string(err)}
              </p>
            </div>

            <%!-- Server-owned: written by the upload progress callback, never by
                  the client; round-trips the persisted key through autosaves. --%>
            <input type="hidden" name="question[solution_video_key]" value={solution_video} />

            <div :if={solution_video} class="space-y-2">
              <video
                src={Quiz.Storage.url(solution_video)}
                controls
                preload="metadata"
                playsinline
                class="max-h-48 max-w-md rounded-box bg-black"
              >
              </video>
              <button
                type="button"
                id="remove-solution-video"
                phx-click="remove_solution_video"
                class="btn btn-ghost btn-sm text-error"
              >
                <.icon name="hero-trash" class="size-4" /> Video entfernen
              </button>
            </div>
          </div>
        </div>
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
     |> assign(:mode, initial_mode(socket.assigns.live_action, locked, questions))
     |> OpenRun.assign_defaults()
     |> assign(:insert_at, nil)
     |> assign(review_step: :question, review_index: 1, review_editing: false)
     |> assign(:selected_question, nil)
     |> assign(:question_type, nil)
     |> assign(:form, nil)
     |> assign(:save_status, nil)
     |> assign(:pending_params, nil)
     |> assign(:pin_uploaded_key, nil)
     |> assign(:media_uploaded_key, nil)
     |> assign(:media_video_uploaded_key, nil)
     |> assign(:solution_uploaded_key, nil)
     |> assign(:solution_video_uploaded_key, nil)
     |> assign(:media_tab, :image)
     |> assign(:solution_tab, :image)
     |> allow_upload(:pin_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       # There is no submit button — the form persists via autosave on
       # "validate". Uploads are consumed in handle_pin_image_progress/3 the
       # moment the file finishes streaming, independent of the validate churn,
       # which keeps the upload lifecycle deterministic.
       auto_upload: true,
       progress: &handle_pin_image_progress/3
     )
     |> allow_upload(:media_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_media_image_progress/3
     )
     |> allow_upload(:media_video,
       accept: ~w(.mp4 .webm),
       max_entries: 1,
       max_file_size: 50_000_000,
       auto_upload: true,
       progress: &handle_media_video_progress/3
     )
     |> allow_upload(:solution_image,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_solution_image_progress/3
     )
     |> allow_upload(:solution_video,
       accept: ~w(.mp4 .webm),
       max_entries: 1,
       max_file_size: 50_000_000,
       auto_upload: true,
       progress: &handle_solution_video_progress/3
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    socket
    |> assign(:page_title, "Fragen")
    |> assign(:insert_at, parse_insert_at(params["at"], length(socket.assigns.questions)))
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

  defp apply_action(socket, :review, params) do
    game = socket.assigns.game
    count = length(socket.assigns.questions)

    cond do
      socket.assigns.locked ->
        push_navigate(socket, to: ~p"/games/#{game}/questions")

      Map.has_key?(params, "ablauf") ->
        socket
        |> assign(:page_title, "Ablauf festlegen")
        |> assign(:review_step, :settings)
        |> assign(:review_editing, false)
        |> assign(
          :settings_form,
          to_form(
            %{"review_mode" => game.review_mode, "show_statistics" => game.show_statistics},
            as: :settings
          )
        )

      true ->
        case Integer.parse(params["frage"] || "1") do
          {index, ""} when index in 1..count//1 ->
            question = Enum.at(socket.assigns.questions, index - 1)

            socket
            |> authoring_action(:edit, %{"id" => question.id})
            |> assign(:page_title, "Fragen prüfen")
            |> assign(:review_step, :question)
            |> assign(:review_index, index)
            |> assign(:review_editing, false)

          _past_the_last ->
            push_patch(socket, to: ~p"/games/#{game}/durchsicht?ablauf")
        end
    end
  end

  defp review_path(game, index), do: ~p"/games/#{game}/durchsicht?#{[frage: index]}"

  # «Ansehen» is the default view of a quiz. A link to one question opens its
  # form, and an empty quiz opens the type picker — there is nothing to look at.
  defp initial_mode(_action, true = _locked, _questions), do: :view
  defp initial_mode(:edit, _locked, _questions), do: :edit
  defp initial_mode(_action, _locked, []), do: :edit
  defp initial_mode(_action, _locked, _questions), do: :view

  # «Frage hinzufügen» between two questions in «Ansehen» passes where the new
  # question goes (`?at=`); without it the question is appended.
  defp parse_insert_at(nil, _count), do: nil

  defp parse_insert_at(at, count) do
    case Integer.parse(at) do
      {index, ""} when index >= 0 and index < count -> index
      _ -> nil
    end
  end

  defp create_question(%{assigns: %{insert_at: index}} = socket, type) when is_integer(index),
    do: Games.create_question(socket.assigns.current_scope, socket.assigns.game, type, at: index)

  defp create_question(socket, type),
    do: Games.create_question(socket.assigns.current_scope, socket.assigns.game, type)

  defp authoring_action(socket, :edit, %{"id" => id}) do
    question = Games.get_question!(socket.assigns.current_scope, id)
    changeset = Games.change_question(socket.assigns.current_scope, question)

    socket
    |> assign(:page_title, "Frage bearbeiten")
    |> assign(:selected_question, question)
    |> assign(:question_type, question.type)
    |> assign(:form, to_form(changeset))
    |> assign(:save_status, nil)
    |> assign(:pending_params, nil)
    |> assign(:pin_uploaded_key, nil)
    |> assign(:media_uploaded_key, nil)
    |> assign(:media_video_uploaded_key, nil)
    |> assign(:solution_uploaded_key, nil)
    |> assign(:solution_video_uploaded_key, nil)
    |> assign(:media_tab, if(question.media_video_key, do: :video, else: :image))
    |> assign(:solution_tab, if(question.solution_video_key, do: :video, else: :image))
  end

  @impl true
  def handle_event(event, params, socket)
      when event in ["open_run", "open_run_skipping", "dismiss_incomplete"],
      do: OpenRun.handle_event(event, params, socket)

  def handle_event("review_edit", _params, socket),
    do: {:noreply, assign(socket, :review_editing, true)}

  def handle_event("review_done", _params, socket),
    do: {:noreply, assign(socket, :review_editing, false)}

  # The list shrinks by one, so the same position now holds the next question.
  def handle_event("review_discard", _params, socket) do
    %{current_scope: scope, game: game, selected_question: question} = socket.assigns

    case Games.delete_question(scope, question) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:questions, Games.list_questions_for_game(scope, game))
         |> push_patch(to: review_path(game, socket.assigns.review_index))}

      {:error, :run_locked} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game}/questions")}
    end
  end

  def handle_event("save_settings", %{"settings" => params}, socket) do
    %{current_scope: scope, game: game} = socket.assigns
    settings = QuizWeb.GameLive.Import.settings_from_params(params)

    case Games.update_game(scope, game, settings) do
      {:ok, game} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game}/questions")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Die Einstellungen konnten nicht gespeichert werden.")}
    end
  end

  def handle_event("set_mode", %{"mode" => "view"}, socket) do
    {:noreply, assign(socket, :mode, :view)}
  end

  def handle_event("set_mode", %{"mode" => _}, socket) do
    {:noreply, assign(socket, :mode, if(socket.assigns.locked, do: :view, else: :edit))}
  end

  def handle_event("add_question_at", %{"at" => at}, socket) do
    {:noreply,
     socket
     |> assign(:mode, :edit)
     |> push_patch(to: ~p"/games/#{socket.assigns.game}/questions?#{[at: at]}")}
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
        case create_question(socket, type) do
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
    {:noreply,
     socket
     |> assign(:pending_params, question_params)
     |> autosave(question_params)}
  end

  # Pure UI: switching the media tab never clears anything — exclusivity is
  # resolved at write time in the changeset the moment the other medium is set.
  def handle_event("media_tab", %{"tab" => tab}, socket) when tab in ["image", "video"] do
    {:noreply, assign(socket, :media_tab, String.to_existing_atom(tab))}
  end

  def handle_event("solution_tab", %{"tab" => tab}, socket) when tab in ["image", "video"] do
    {:noreply, assign(socket, :solution_tab, String.to_existing_atom(tab))}
  end

  def handle_event("remove_media_image", _params, socket) do
    params =
      (socket.assigns.pending_params || base_media_params(socket))
      |> Map.put("media_image_key", "")

    {:noreply,
     socket
     |> assign(:media_uploaded_key, nil)
     |> assign(:pending_params, params)
     |> autosave(params)}
  end

  def handle_event("remove_solution_image", _params, socket) do
    params =
      (socket.assigns.pending_params || base_media_params(socket))
      |> Map.put("solution_image_key", "")

    {:noreply,
     socket
     |> assign(:solution_uploaded_key, nil)
     |> assign(:pending_params, params)
     |> autosave(params)}
  end

  def handle_event("remove_solution_video", _params, socket) do
    params =
      (socket.assigns.pending_params || base_media_params(socket))
      |> Map.put("solution_video_key", "")

    {:noreply,
     socket
     |> assign(:solution_video_uploaded_key, nil)
     |> assign(:pending_params, params)
     |> autosave(params)}
  end

  def handle_event("remove_media_video", _params, socket) do
    params =
      (socket.assigns.pending_params || base_media_params(socket))
      |> Map.put("media_video_key", "")

    {:noreply,
     socket
     |> assign(:media_video_uploaded_key, nil)
     |> assign(:pending_params, params)
     |> autosave(params)}
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
  # A just-uploaded background image's key is injected into the params here so
  # it becomes part of the changeset on the very next autosave — this is what
  # lets a brand-new pin question (which starts with no image) become valid and
  # save, regardless of whether the prompt was typed before or after the upload.
  defp autosave(socket, question_params) do
    question_params = inject_uploaded_key(socket, question_params)

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
            # The uploaded keys are now persisted on the record; clear the
            # pending markers so we don't keep re-injecting them on later
            # autosaves.
            |> assign(:pin_uploaded_key, nil)
            |> assign(:media_uploaded_key, nil)
            |> assign(:media_video_uploaded_key, nil)
            |> assign(:solution_uploaded_key, nil)
            |> assign(:solution_video_uploaded_key, nil)
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

  defp save_question(socket, :review, question_params),
    do: {:noreply, autosave(socket, question_params)}

  defp save_question(socket, :edit, question_params) do
    question_params = inject_uploaded_key(socket, question_params)

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

  # Consumes the background image exactly once, the moment its upload finishes.
  # Using the upload :progress callback (rather than consuming inside "validate")
  # keeps the lifecycle deterministic: the file is persisted to storage as soon
  # as it is complete, regardless of how the surrounding form events interleave.
  #
  # The returned key is stashed in :pin_uploaded_key and an autosave is run with
  # the last form params so the key is written to the record immediately when
  # the rest of the question is already valid. If it is not yet valid (e.g. the
  # prompt is still empty), the key is retained and injected into the next
  # autosave, so it is never lost.
  def handle_pin_image_progress(:pin_image, entry, socket) do
    if entry.done? do
      # Wrap the storage result in `{:ok, ...}`: consume_uploaded_entries raises
      # on anything that isn't `{:ok, _}`/`{:postpone, _}`, so returning a bare
      # `{:error, _}` from `Quiz.Storage.put/3` (a network blip, bad R2
      # credentials, unreadable temp file) would crash the editor. Wrapping lets
      # us surface a flash instead.
      consumed =
        consume_uploaded_entries(socket, :pin_image, fn %{path: path}, entry ->
          {:ok,
           Quiz.Storage.put(socket.assigns.current_scope, path,
             content_type: entry.client_type,
             filename: entry.client_name
           )}
        end)

      case consumed do
        [{:ok, key} | _] ->
          params = socket.assigns.pending_params || base_pin_params(socket)

          {:noreply,
           socket
           |> assign(:pin_uploaded_key, key)
           |> autosave(params)}

        [{:error, _reason} | _] ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Das Bild konnte nicht hochgeladen werden. Bitte versuch es erneut."
           )}

        [] ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Merges pending uploaded storage keys (pin background and/or question media)
  # into the params. A no-op when no new file is awaiting persistence.
  defp inject_uploaded_key(socket, question_params) do
    question_params =
      case socket.assigns[:pin_uploaded_key] do
        key when is_binary(key) -> put_pin_image_key(question_params, key)
        _ -> question_params
      end

    question_params =
      case socket.assigns[:media_uploaded_key] do
        key when is_binary(key) -> Map.put(question_params, "media_image_key", key)
        _ -> question_params
      end

    question_params =
      case socket.assigns[:media_video_uploaded_key] do
        key when is_binary(key) -> Map.put(question_params, "media_video_key", key)
        _ -> question_params
      end

    question_params =
      case socket.assigns[:solution_uploaded_key] do
        key when is_binary(key) -> Map.put(question_params, "solution_image_key", key)
        _ -> question_params
      end

    case socket.assigns[:solution_video_uploaded_key] do
      key when is_binary(key) -> Map.put(question_params, "solution_video_key", key)
      _ -> question_params
    end
  end

  defp put_pin_image_key(params, key) do
    data = Map.get(params, "data", %{})
    pin = data |> Map.get("pin", %{}) |> Map.put("image_key", key)
    Map.put(params, "data", Map.put(data, "pin", pin))
  end

  # Consumes a question-media file (image or video) exactly once, the moment
  # its upload finishes — same deterministic lifecycle as
  # handle_pin_image_progress/3. The key is stashed in the given assign and
  # injected into autosaves via inject_uploaded_key/2 until it is persisted.
  def handle_media_image_progress(:media_image, entry, socket) do
    handle_media_progress(:media_image, :media_uploaded_key, "Das Bild", entry, socket)
  end

  def handle_media_video_progress(:media_video, entry, socket) do
    handle_media_progress(:media_video, :media_video_uploaded_key, "Das Video", entry, socket)
  end

  def handle_solution_image_progress(:solution_image, entry, socket) do
    handle_media_progress(:solution_image, :solution_uploaded_key, "Das Bild", entry, socket)
  end

  def handle_solution_video_progress(:solution_video, entry, socket) do
    handle_media_progress(
      :solution_video,
      :solution_video_uploaded_key,
      "Das Video",
      entry,
      socket
    )
  end

  defp handle_media_progress(upload_name, assign_key, noun, entry, socket) do
    if entry.done? do
      consumed =
        consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
          {:ok,
           Quiz.Storage.put(socket.assigns.current_scope, path,
             content_type: entry.client_type,
             filename: entry.client_name
           )}
        end)

      case consumed do
        [{:ok, key} | _] ->
          params = socket.assigns.pending_params || base_media_params(socket)

          {:noreply,
           socket
           |> assign(assign_key, key)
           |> autosave(params)}

        [{:error, _reason} | _] ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "#{noun} konnte nicht hochgeladen werden. Bitte versuch es erneut."
           )}

        [] ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Minimal, well-formed params used when a media action (upload/remove)
  # happens before any "validate" has run, so there are no stashed form params
  # yet. Leaves the type-specific data untouched.
  defp base_media_params(socket) do
    question = socket.assigns.selected_question

    %{
      "type" => Atom.to_string(question.type),
      "prompt" => question.prompt || "",
      "position" => to_string(question.position)
    }
  end

  # Minimal, well-formed pin params used when the upload completes before any
  # "validate" has run (so we have no stashed form params yet). Carries the
  # question's current prompt/position and default pin coordinates.
  defp base_pin_params(socket) do
    question = socket.assigns.selected_question

    %{
      "type" => "pin_on_image",
      "prompt" => question.prompt || "",
      "position" => to_string(question.position),
      "data" => %{
        "pin" => %{
          "target_x" => to_string(pin_coord(socket.assigns.form, :target_x)),
          "target_y" => to_string(pin_coord(socket.assigns.form, :target_y)),
          "radius" => to_string(pin_coord(socket.assigns.form, :radius)),
          "aspect_ratio" => to_string(pin_coord(socket.assigns.form, :aspect_ratio))
        }
      }
    }
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

  # A question that does not yet meet the playable bar (see `Question.ready?/1`);
  # the quiz can't be opened until every question is complete.
  defp incomplete?(question), do: not Quiz.Games.Question.ready?(question)

  defp padded_count(questions), do: pad(length(questions))
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp selected?(nil, _question), do: false
  defp selected?(%{id: id}, %{id: id}), do: true
  defp selected?(_, _), do: false

  defp type_letter(:single_choice), do: "S"
  defp type_letter(:multiple_choice), do: "M"
  defp type_letter(:text_input), do: "T"
  defp type_letter(:sequence), do: "R"
  defp type_letter(:pin_on_image), do: "P"
  defp type_letter(:matching), do: "Z"
  defp type_letter(:number_range), do: "N"
  defp type_letter(_), do: "?"

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

  defp number_range_struct(%{source: %Ecto.Changeset{} = cs}) do
    case Ecto.Changeset.get_field(cs, :data) do
      %{number_range: %NumberRange{} = nr} -> nr
      _ -> nil
    end
  end

  defp number_range_struct(_), do: nil

  defp nr_field(form, field) do
    case number_range_struct(form) do
      %NumberRange{} = nr -> Map.get(nr, field)
      _ -> nil
    end
  end

  defp number_range_band(form) do
    case number_range_struct(form) do
      %NumberRange{solution: s, tolerance: t} when is_integer(s) and is_integer(t) ->
        "#{s - t} – #{s + t}"

      _ ->
        nil
    end
  end

  defp pin_image_key(form) do
    case pin_struct(form) do
      %Pin{image_key: key} when is_binary(key) and key != "" -> key
      _ -> nil
    end
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true
  attr :search, :boolean, default: false, doc: "offer an image search for `text`"

  # A note from the text import (`Question.image_hint`/`pin_hint`) on what the
  # author still has to add by hand.
  defp author_hint(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex items-start gap-3 rounded-box border border-info/30 bg-info/5 p-4 text-sm"
    >
      <.icon name={@icon} class="mt-0.5 size-5 shrink-0 text-info" />
      <div class="min-w-0">
        <p class="font-semibold text-base-content">{@title}</p>
        <p class="mt-0.5 text-base-content/70">{@text}</p>
        <a
          :if={@search}
          href={
            "https://commons.wikimedia.org/w/index.php?" <>
              URI.encode_query(search: @text, title: "Special:MediaSearch", type: "image")
          }
          target="_blank"
          rel="noopener noreferrer"
          class="mt-2 inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
        >
          Passendes Bild auf Wikimedia Commons suchen (Lizenz beachten)
          <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
        </a>
      </div>
    </div>
    """
  end

  defp present?(value), do: value not in [nil, ""]

  defp media_image_key(form), do: media_key(form, :media_image_key)
  defp media_video_key(form), do: media_key(form, :media_video_key)
  defp solution_image_key(form), do: media_key(form, :solution_image_key)
  defp solution_video_key(form), do: media_key(form, :solution_video_key)

  defp media_key(form, field) do
    case form[field].value do
      key when is_binary(key) and key != "" -> key
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

  defp video_upload_error_to_string(:too_large), do: "Datei ist zu groß (max. 50 MB)."
  defp video_upload_error_to_string(:not_accepted), do: "Nur MP4 oder WEBM."
  defp video_upload_error_to_string(err), do: upload_error_to_string(err)

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
