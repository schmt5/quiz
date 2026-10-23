defmodule QuizWeb.GameLive.Import do
  @moduledoc """
  Creates a quiz with the author's own AI chat: hand the chat the prompt, paste
  its answer back, check the live preview and create a draft.

  Nothing is sent to an AI provider from here — the round trip goes through the
  author's clipboard, so it works with any chat, free tiers included.
  """
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.{Question, TextFormat}
  alias QuizWeb.QuestionLive.AnswerArea

  @default_params %{"text" => "", "review_mode" => "per_question", "show_statistics" => "true"}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-10">
        <div>
          <div class="breadcrumbs text-xs">
            <ul>
              <li>
                <.link navigate={~p"/"} aria-label="Home">
                  <.icon name="hero-home" class="size-4" />
                </.link>
              </li>
              <li :if={!@anonymous}><.link navigate={~p"/games"}>Quizze</.link></li>
              <li>Mit KI erstellen</li>
            </ul>
          </div>
          <h1 class="text-2xl sm:text-3xl font-bold">Quiz mit deiner KI erstellen</h1>
          <p class="mt-1 max-w-2xl text-base-content/60">
            Du arbeitest das Quiz mit der KI aus, die du gewohnt bist – ChatGPT, Claude oder eine
            andere. Am Schluss kopierst du ihre Antwort hierher zurück.
          </p>
        </div>

        <div class="grid gap-3 md:grid-cols-[1fr_auto_1fr] md:gap-4">
          <section
            id="ai-step-prompt"
            class="rounded-box border border-base-200 bg-base-100 p-6 shadow-sm"
          >
            <.step_title number={1} title="Gib deiner KI diesen Prompt" />
            <p class="mt-2 text-sm text-base-content/60">
              Öffne einen neuen Chat mit dem Prompt. Die KI fragt dich nach Thema, Zielgruppe und
              Anzahl Fragen und schlägt dir dann ein Quiz vor, das du mit ihr anpassen kannst.
            </p>

            <div class="mt-5 flex flex-wrap gap-2">
              <a
                id="open-chatgpt"
                href={"https://chatgpt.com/?q=" <> URI.encode_www_form(@prompt)}
                target="_blank"
                rel="noopener noreferrer"
                class="btn btn-primary"
              >
                In ChatGPT öffnen <.icon name="hero-arrow-top-right-on-square" class="size-4" />
              </a>
              <a
                id="open-claude"
                href={"https://claude.ai/new?q=" <> URI.encode_www_form(@prompt)}
                target="_blank"
                rel="noopener noreferrer"
                class="btn btn-primary"
              >
                In Claude öffnen <.icon name="hero-arrow-top-right-on-square" class="size-4" />
              </a>
              <.copy_button id="copy-prompt" from="ai-prompt" class="btn btn-soft">
                Prompt kopieren
              </.copy_button>
            </div>
            <p class="mt-3 text-xs text-base-content/50">
              Andere KI? Kopiere den Prompt und füge ihn in einen neuen Chat ein.
            </p>

            <details class="group mt-4">
              <summary class="cursor-pointer text-sm font-medium text-base-content/60 transition hover:text-base-content">
                Prompt ansehen
              </summary>
              <textarea
                id="ai-prompt"
                readonly
                rows="12"
                class="mt-3 w-full rounded-field border border-base-300/70 bg-base-200/40 p-3 font-mono text-xs text-base-content/70"
              >{@prompt}</textarea>
            </details>
          </section>

          <div class="flex items-center justify-center text-primary/40" aria-hidden="true">
            <.icon name="hero-arrow-long-right" class="hidden size-8 md:block" />
            <.icon name="hero-arrow-long-down" class="size-8 md:hidden" />
          </div>

          <section
            id="ai-step-paste"
            class="rounded-box border border-base-200 bg-base-100 p-6 shadow-sm"
          >
            <.step_title number={2} title="Füge die Antwort der KI hier ein" />
            <p class="mt-2 text-sm text-base-content/60">
              Wenn das Quiz passt, kopiere den Block mit dem Kopieren-Knopf der KI und füge ihn hier
              ein. Es macht nichts, wenn etwas Text davor oder danach mitkommt.
            </p>

            <%!-- Visitors without an account post the text to
                 GuestImportController (phx-trigger-action), which creates the
                 guest account — a LiveView cannot write the session cookie.
                 «Als Entwurf anlegen» below opens the options dialog, which sits
                 inside this form so its choices are submitted with the text. --%>
            <.form
              for={@form}
              id="import-form"
              action={~p"/erstellen"}
              method="post"
              phx-change="preview"
              phx-submit="create"
              phx-trigger-action={@trigger_submit}
              class="mt-4"
            >
              <.input
                field={@form[:text]}
                type="textarea"
                rows="9"
                phx-debounce="300"
                placeholder={placeholder()}
                class="font-mono !text-sm"
                aria-label="Antwort der KI"
              />
              <.options_dialog form={@form} />
            </.form>

            <p
              :if={@anonymous or @guest}
              id="guest-notice"
              class="mt-1 rounded-field bg-base-200/60 px-3 py-2 text-xs text-base-content/60"
            >
              {if @anonymous,
                do: "Ohne Konto legen wir dir einen Gastzugang an.",
                else: "Du bist als Gast unterwegs."} Deine Quizze werden nach {Quiz.Accounts.guest_lifetime_days()} Tagen gelöscht –
              <.link
                navigate={~p"/users/register"}
                class="font-medium text-primary hover:underline"
              >
                mit einem Konto
              </.link>
              behältst du sie.
            </p>

            <Layouts.guest_limit_note :if={@limit_reached} class="mt-3" />
          </section>
        </div>

        <section
          id="import-preview"
          phx-hook=".ScrollIntoView"
          class="scroll-mt-6"
          aria-live="polite"
        >
          <.preview result={@result} loading={@loading} limit_reached={@limit_reached} />
        </section>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".ScrollIntoView">
        export default {
          mounted() {
            this.handleEvent("scroll-to-preview", () =>
              this.el.scrollIntoView({ behavior: "smooth", block: "start" })
            )
          }
        }
      </script>
    </Layouts.app>
    """
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true

  defp step_title(assigns) do
    ~H"""
    <h2 class="flex items-center gap-3 text-lg font-bold">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary text-sm text-primary-content">
        {@number}
      </span>
      {@title}
    </h2>
    """
  end

  attr :result, :any, required: true
  attr :loading, :boolean, required: true
  attr :limit_reached, :boolean, required: true

  defp preview(%{loading: true} = assigns) do
    ~H"""
    <div
      id="preview-loading"
      role="status"
      class="flex min-h-[60vh] flex-col items-center justify-center gap-10 rounded-box border border-base-200 bg-base-100 px-6 py-16 shadow-sm"
    >
      <span class="sr-only">Dein Quiz wird vorbereitet</span>
      <%!-- A teal-to-mimosa ring turning around a pulsing spark --%>
      <div class="relative size-28" aria-hidden="true">
        <div class="absolute inset-0 animate-spin rounded-full bg-[conic-gradient(from_0deg,transparent_0deg,var(--color-secondary)_200deg,var(--color-primary)_360deg)] [animation-duration:1.1s] [mask:radial-gradient(farthest-side,transparent_calc(100%-7px),#000_calc(100%-6px))]">
        </div>
        <div class="absolute inset-4 rounded-full bg-secondary/25 animate-ping [animation-duration:1.8s]">
        </div>
        <div class="absolute inset-0 grid place-items-center">
          <.icon name="hero-sparkles" class="size-10 text-primary animate-pulse" />
        </div>
      </div>
      <%!-- Question cards taking shape one after the other --%>
      <div class="w-full max-w-md space-y-3" aria-hidden="true">
        <div
          :for={{delay, width} <- [{"0ms", "w-11/12"}, {"200ms", "w-9/12"}, {"400ms", "w-10/12"}]}
          class="flex items-center gap-3 rounded-box bg-base-200/70 p-3 animate-pulse"
          style={"animation-delay: #{delay}"}
        >
          <span class="size-8 shrink-0 rounded-lg bg-primary/15"></span>
          <span class={["h-3 rounded-full bg-base-300", width]}></span>
        </div>
      </div>
    </div>
    """
  end

  defp preview(%{result: nil} = assigns) do
    ~H"""
    <div
      id="preview-empty"
      class="rounded-box border border-dashed border-base-300 bg-base-200/40 p-10 text-center"
    >
      <span class="mx-auto flex size-14 items-center justify-center rounded-2xl bg-primary/15 text-primary">
        <.icon name="hero-sparkles" class="size-7" />
      </span>
      <h2 class="mt-4 text-lg font-bold">Hier erscheint dein Quiz</h2>
      <p class="mt-1 text-sm text-base-content/55">
        Sobald du die Antwort der KI einfügst, siehst du hier alle Fragen so, wie die Teams sie
        sehen.
      </p>
    </div>
    """
  end

  defp preview(%{result: {:error, :no_questions}} = assigns) do
    ~H"""
    <div id="preview-error" class="rounded-box border border-error/30 bg-error/5 p-6">
      <h2 class="flex items-center gap-2 font-bold text-error">
        <.icon name="hero-exclamation-triangle" class="size-5" /> Keine Fragen gefunden
      </h2>
      <p class="mt-2 text-sm text-base-content/70">
        Jede Frage beginnt mit einer Zeile <code class="font-mono">Frage:</code>. Hast du den ganzen
        Block der KI kopiert? Sonst bitte die KI, das Quiz nochmals vollständig im vereinbarten Format
        auszugeben.
      </p>
    </div>
    """
  end

  defp preview(%{result: {:ok, parsed}} = assigns) do
    questions = preview_questions(parsed.questions)

    assigns =
      assigns
      |> assign(:parsed, parsed)
      |> assign(:questions, questions)
      |> assign(:missing, Enum.map(questions, &missing_requirements/1))
      |> assign(:feedback, feedback_for_ai(parsed.warnings))
      |> assign(:uploads_needed, Enum.count(questions, &needs_upload?/1))

    ~H"""
    <div class="mx-auto max-w-3xl space-y-6">
      <div class="rounded-box border border-base-200 bg-base-100 p-6 shadow-sm">
        <div class="flex flex-wrap items-start justify-between gap-4">
          <div class="min-w-0">
            <p class="text-xs font-medium uppercase tracking-wider text-base-content/45">Vorschau</p>
            <h2 id="preview-title" class="mt-1 text-xl font-bold leading-tight">{@parsed.title}</h2>
            <p class="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-sm text-base-content/60">
              <span id="preview-count">{question_count(length(@questions))}</span>
              <span
                :if={@uploads_needed > 0}
                id="preview-uploads"
                class="font-medium text-base-content/75"
              >
                <.icon name="hero-photo" class="size-4 align-[-3px]" />
                {upload_count(@uploads_needed)} danach hochladen
              </span>
            </p>
          </div>
          <.create_button :if={!@limit_reached} id="create-quiz" />
        </div>
        <p
          id="manual-editing-info"
          class="mt-4 flex items-start gap-2 rounded-field bg-base-200/60 px-3 py-2 text-sm text-base-content/70"
        >
          <.icon name="hero-pencil-square" class="mt-0.5 size-4 shrink-0 text-primary" />
          <span>
            Sobald der Entwurf steht, kannst du jede Frage von Hand bearbeiten, ergänzen, umstellen
            oder löschen.
          </span>
        </p>
      </div>

      <div
        :if={@parsed.warnings != []}
        id="preview-warnings"
        class="rounded-box border border-warning/40 bg-warning/10 p-5"
      >
        <h3 class="flex items-center gap-2 font-semibold">
          <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
          Nicht alles war eindeutig
        </h3>
        <ul class="mt-2 list-disc space-y-1 pl-5 text-sm text-base-content/75">
          <li :for={warning <- @parsed.warnings}>{warning}</li>
        </ul>
        <p class="mt-3 text-sm text-base-content/60">
          Du kannst trotzdem anlegen und es im Editor korrigieren – oder die Hinweise der KI geben:
        </p>
        <textarea id="ai-feedback" class="hidden" readonly>{@feedback}</textarea>
        <.copy_button id="copy-feedback" from="ai-feedback" class="btn btn-sm btn-soft mt-2">
          Hinweise für die KI kopieren
        </.copy_button>
      </div>

      <%!-- The same cards as the editor's «Ansehen» view: each question as the
           teams will see it, without its solution. --%>
      <div id="preview-questions" class="space-y-6">
        <article
          :for={{{question, missing}, index} <- Enum.with_index(Enum.zip(@questions, @missing), 1)}
          id={"preview-question-#{index}"}
          class="rounded-box border border-base-300 bg-base-100 p-6 space-y-4"
        >
          <p class="font-mono text-xs uppercase tracking-wider text-base-content/60">
            Frage {pad(index)} · {type_name(question.type)}
          </p>
          <h2 class="text-xl font-bold">
            {if question.prompt in [nil, ""], do: "(ohne Fragetext)", else: question.prompt}
          </h2>
          <.rich_text html={question.description} />
          <.image_placeholder
            :if={question.type != :pin_on_image and question.image_hint not in [nil, ""]}
            hint={question.image_hint}
          />
          <%!-- Its own form keeps radio groups apart and stops Enter from
               submitting anything. --%>
          <form id={"preview-answer-#{index}"} phx-submit="ignore_preview_answer">
            <.preview_answer question={question} />
          </form>
          <p
            :if={missing != []}
            class="flex gap-2 rounded-field bg-warning/10 px-3 py-2 text-sm"
          >
            <.icon name="hero-pencil-square" class="size-4 shrink-0 mt-0.5 text-warning" />
            <span>Im Editor ergänzen: {Enum.join(missing, ", ")}</span>
          </p>
        </article>
      </div>

      <div :if={!@limit_reached} class="flex justify-center">
        <.create_button id="create-quiz-bottom" />
      </div>
    </div>
    """
  end

  attr :id, :string, required: true

  defp create_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      onclick={open_modal("import_options_modal")}
      class="btn btn-primary btn-lg"
    >
      Als Entwurf anlegen <span aria-hidden="true">→</span>
    </button>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true

  # The two choices that matter before the first run, asked after «Als Entwurf
  # anlegen». It lives inside the import form, so it cannot use method="dialog"
  # forms (no nested forms): closing goes through the dialog element directly.
  defp options_dialog(assigns) do
    ~H"""
    <%!-- Keep the browser-set `open` across re-renders (choosing an option
         triggers phx-change), or the dialog would close on every click. --%>
    <dialog
      id="import_options_modal"
      class="modal"
      phx-mounted={JS.ignore_attributes(["open"])}
    >
      <div class="modal-box max-w-2xl overflow-hidden p-0">
        <div class="p-6 sm:p-8">
          <p class="text-xs font-semibold uppercase tracking-widest text-primary/70">
            Fast geschafft
          </p>
          <h2 class="mt-1 text-2xl font-bold">Wie soll dein Quiz ablaufen?</h2>
          <p class="mt-1 text-sm text-base-content/60">Beides kannst du später jederzeit ändern.</p>

          <fieldset class="mt-7">
            <legend class="text-sm font-semibold">Wann zeigst du die Musterlösung?</legend>
            <div class="mt-3 grid gap-3 sm:grid-cols-2">
              <.option_card
                id="review-mode-per-question"
                field={@form[:review_mode]}
                value="per_question"
                icon="hero-chat-bubble-left-right"
                title="Nach jeder Frage"
                recommended
              >
                Du löst jede Frage gleich auf und besprichst sie mit den Teams.
              </.option_card>
              <.option_card
                id="review-mode-end"
                field={@form[:review_mode]}
                value="end"
                icon="hero-flag"
                title="Am Ende des Quiz"
              >
                Erst alle Fragen spielen, dann gemeinsam alle Lösungen durchgehen.
              </.option_card>
            </div>
          </fieldset>

          <fieldset class="mt-7">
            <legend class="text-sm font-semibold">Statistik in der Besprechung</legend>
            <label class="mt-3 flex cursor-pointer items-center gap-4 rounded-box border-2 border-base-300 p-4 transition hover:border-primary/40 has-checked:border-primary has-checked:bg-primary/5">
              <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-secondary/40 text-primary">
                <.icon name="hero-chart-bar" class="size-5" />
              </span>
              <span class="flex-1">
                <span class="block font-semibold">Antwortverteilung zeigen</span>
                <span class="block text-sm text-base-content/60">
                  Bei der Auflösung sehen alle, wie die Teams geantwortet haben – ein guter
                  Einstieg in die Diskussion.
                </span>
              </span>
              <input type="hidden" name={@form[:show_statistics].name} value="false" />
              <input
                id="show-statistics"
                type="checkbox"
                name={@form[:show_statistics].name}
                value="true"
                checked={@form[:show_statistics].value == "true"}
                class="toggle toggle-primary"
              />
            </label>
          </fieldset>
        </div>

        <div class="flex items-center justify-end gap-2 border-t border-base-200 bg-base-200/50 px-6 py-4 sm:px-8">
          <button
            type="button"
            class="btn btn-ghost"
            onclick="document.getElementById('import_options_modal').close()"
          >
            Zurück
          </button>
          <button
            id="confirm-create-quiz"
            type="submit"
            phx-disable-with="Quiz wird erstellt …"
            class="btn btn-primary"
          >
            Quiz erstellen <span aria-hidden="true">→</span>
          </button>
        </div>
      </div>
      <div class="modal-backdrop" onclick="this.closest('dialog').close()"></div>
    </dialog>
    """
  end

  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :recommended, :boolean, default: false
  slot :inner_block, required: true

  defp option_card(assigns) do
    ~H"""
    <label
      for={@id}
      class="group relative flex cursor-pointer flex-col gap-2 rounded-box border-2 border-base-300 bg-base-100 p-4 transition hover:border-primary/40 has-checked:border-primary has-checked:bg-primary/5"
    >
      <input
        id={@id}
        type="radio"
        name={@field.name}
        value={@value}
        checked={@field.value == @value}
        class="sr-only"
      />
      <div class="flex items-center gap-2">
        <span class="flex size-10 items-center justify-center rounded-xl bg-base-200 text-base-content/60 transition group-has-checked:bg-primary group-has-checked:text-primary-content">
          <.icon name={@icon} class="size-5" />
        </span>
        <span :if={@recommended} class="badge badge-soft badge-primary badge-sm">Empfohlen</span>
        <.icon
          name="hero-check-circle-solid"
          class="ml-auto size-6 text-primary opacity-0 transition group-has-checked:opacity-100"
        />
      </div>
      <span class="font-semibold">{@title}</span>
      <span class="text-sm text-base-content/60">{render_slot(@inner_block)}</span>
    </label>
    """
  end

  attr :hint, :string, required: true

  defp image_placeholder(assigns) do
    ~H"""
    <div class="flex aspect-video max-w-md flex-col items-center justify-center gap-2 rounded-box border-2 border-dashed border-base-300 bg-base-200/60 p-6 text-center">
      <.icon name="hero-photo" class="size-8 text-base-content/35" />
      <p class="text-sm font-semibold text-base-content/60">Bild folgt</p>
      <p class="text-xs text-base-content/50">{@hint}</p>
    </div>
    """
  end

  attr :question, Question, required: true

  defp preview_answer(%{question: %{type: :pin_on_image}} = assigns) do
    ~H"""
    <.image_placeholder hint={@question.image_hint || "Bild für den Pin"} />
    """
  end

  defp preview_answer(%{question: %{type: :number_range, data: %{number_range: nil}}} = assigns),
    do: ~H""

  defp preview_answer(assigns) do
    ~H"""
    <AnswerArea.answer_area question={AnswerArea.prepare_question(@question)} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    anonymous = is_nil(scope)

    if anonymous and not Quiz.Accounts.guest_mode_enabled?() do
      {:ok,
       socket
       |> put_flash(:error, "Bitte melde dich an, um ein Quiz zu erstellen.")
       |> redirect(to: ~p"/users/log-in")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Quiz mit KI erstellen")
       |> assign(:prompt, TextFormat.prompt())
       |> assign(:anonymous, anonymous)
       |> assign(:guest, not anonymous and Quiz.Accounts.guest?(scope.user))
       |> assign(:limit_reached, not anonymous and Games.guest_limit_reached?(scope))
       |> assign(:trigger_submit, false)
       |> assign(:form, to_form(@default_params, as: :import))
       |> assign(result: nil, loading: false, pending: nil, preview_ref: nil)}
    end
  end

  @impl true
  def handle_event("preview", %{"import" => %{"text" => text} = params}, socket) do
    socket = assign(socket, :form, to_form(Map.merge(@default_params, params), as: :import))
    {:noreply, show_preview(socket, parse(text))}
  end

  def handle_event("ignore_preview_answer", _params, socket), do: {:noreply, socket}

  # No account yet: hand the text to GuestImportController as a regular POST.
  def handle_event("create", _params, %{assigns: %{loading: true}} = socket),
    do: {:noreply, socket}

  def handle_event(
        "create",
        %{"import" => %{"text" => text}},
        %{assigns: %{anonymous: true}} = socket
      ) do
    case parse(text) do
      {:ok, _parsed} -> {:noreply, assign(socket, trigger_submit: true)}
      result -> {:noreply, assign(socket, :result, result)}
    end
  end

  def handle_event("create", %{"import" => %{"text" => text} = params}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, parsed} <- parse(text),
         {:ok, game} <- Games.import_game(scope, parsed, settings_from_params(params)) do
      # Open the first question rather than the editor's "add a question" view.
      [first | _] = Games.list_questions_for_game(scope, game)

      {:noreply,
       socket
       |> put_flash(:info, "Quiz erstellt. Prüfe die Fragen und ergänze, was noch fehlt.")
       |> push_navigate(to: ~p"/games/#{game}/questions/#{first}/edit")}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:result, parse(text))
         |> put_flash(:error, "Das Quiz konnte nicht angelegt werden. Bitte prüfe die Vorschau.")}
    end
  end

  @impl true
  def handle_info({:reveal_preview, ref}, %{assigns: %{preview_ref: ref}} = socket) do
    {:noreply, assign(socket, result: socket.assigns.pending, loading: false, preview_ref: nil)}
  end

  # A reveal that was superseded (the text was cleared meanwhile).
  def handle_info({:reveal_preview, _ref}, socket), do: {:noreply, socket}

  # The first time a pasted quiz is recognised, the preview waits a moment
  # behind a spinner, so it is clear that something is being made of the
  # paste. Later edits update the preview right away.
  defp show_preview(socket, {:ok, _} = result) do
    cond do
      socket.assigns.loading ->
        assign(socket, :pending, result)

      match?({:ok, _}, socket.assigns.result) or preview_delay() == 0 ->
        assign(socket, :result, result)

      true ->
        ref = make_ref()
        Process.send_after(self(), {:reveal_preview, ref}, preview_delay())

        socket
        |> assign(loading: true, pending: result, preview_ref: ref)
        |> push_event("scroll-to-preview", %{})
    end
  end

  defp show_preview(socket, result),
    do: assign(socket, result: result, loading: false, pending: nil, preview_ref: nil)

  defp preview_delay, do: Application.get_env(:quiz, :import_preview_delay, 1800)

  @doc """
  The quiz settings chosen in the options dialog, for `Quiz.Games.import_game/3`.
  Defaults to solutions after every question and the answer statistics shown.
  """
  def settings_from_params(params) do
    %{
      review_mode: if(params["review_mode"] == "end", do: :end, else: :per_question),
      show_statistics: params["show_statistics"] != "false"
    }
  end

  defp placeholder, do: "Format: quiz-text/v1\nQuiz: …\n\nFrage: …"

  defp parse(text) do
    if String.trim(text) == "", do: nil, else: TextFormat.parse(text)
  end

  # The parsed attributes as (unsaved) structs, so the preview can show them with
  # the same `Question.missing_requirements/1` the editor uses.
  defp preview_questions(questions) do
    scope = %Quiz.Accounts.Scope{user: %Quiz.Accounts.User{}}

    for {attrs, position} <- Enum.with_index(questions, 1) do
      %Question{}
      |> Question.changeset(Map.merge(attrs, %{game_id: 0, position: position}), scope, :draft)
      |> Ecto.Changeset.apply_changes()
      |> with_preview_ids(position, attrs)
    end
  end

  # Unsaved questions have no ids, but the answer areas key their DOM (and
  # client-side hooks) by them. The question id changes with the content, so a
  # hook-managed area is rebuilt when the pasted text changes.
  defp with_preview_ids(%Question{data: data} = question, position, attrs) do
    data =
      if data do
        %{
          data
          | choices: numbered(data.choices, "c"),
            solutions: numbered(data.solutions, "s"),
            items: numbered(data.items, "i"),
            pairs: numbered(data.pairs, "p")
        }
      end

    %{question | id: "import-#{position}-#{:erlang.phash2(attrs)}", data: data}
  end

  defp numbered(entries, prefix) do
    for {entry, i} <- Enum.with_index(entries), do: %{entry | id: "#{prefix}#{i}"}
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp missing_requirements(question) do
    case question.type do
      :pin_on_image -> ["Bild hochladen und Pin setzen"]
      _ -> Question.missing_requirements(question)
    end
  end

  defp needs_upload?(%Question{type: :pin_on_image}), do: true
  defp needs_upload?(%Question{image_hint: hint}), do: hint not in [nil, ""]

  defp feedback_for_ai(warnings) do
    """
    Die Quiz-App konnte nicht alles eindeutig lesen:
    #{Enum.map_join(warnings, "\n", &("- " <> &1))}

    Bitte korrigiere das und gib das ganze Quiz nochmals in einem Codeblock im vereinbarten Format aus.
    """
  end

  defp type_name(type), do: Keyword.fetch!(TextFormat.type_names(), type)

  defp question_count(1), do: "1 Frage"
  defp question_count(n), do: "#{n} Fragen"

  defp upload_count(1), do: "1 Bild"
  defp upload_count(n), do: "#{n} Bilder"
end
