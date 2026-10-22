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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-8">
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

        <div class="grid gap-8 lg:grid-cols-2 lg:items-start">
          <div class="space-y-6">
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
                   guest account — a LiveView cannot write the session cookie. --%>
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
                  rows="12"
                  phx-debounce="300"
                  placeholder={placeholder()}
                  class="font-mono !text-sm"
                  aria-label="Antwort der KI"
                />

                <div
                  :if={@limit_reached}
                  id="guest-limit"
                  class="mt-2 rounded-box border border-warning/40 bg-warning/10 p-4 text-sm"
                >
                  Als Gast kannst du höchstens {Games.guest_max_games()} Quizze haben.
                  <.link
                    navigate={~p"/users/register"}
                    class="font-semibold text-primary hover:underline"
                  >
                    Erstelle ein Konto
                  </.link>
                  – deine Quizze bleiben dabei erhalten.
                </div>

                <button
                  :if={!@limit_reached}
                  id="create-quiz"
                  type="submit"
                  disabled={not match?({:ok, _}, @result)}
                  phx-disable-with="Quiz wird erstellt …"
                  class="btn btn-primary btn-lg mt-2 w-full"
                >
                  Als Entwurf anlegen <span aria-hidden="true">→</span>
                </button>
                <p class="mt-2 text-center text-xs text-base-content/50">
                  Du kannst danach alles im Editor anpassen und Bilder ergänzen.
                </p>
                <p
                  :if={@anonymous or @guest}
                  id="guest-notice"
                  class="mt-3 rounded-field bg-base-200/60 px-3 py-2 text-center text-xs text-base-content/60"
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
              </.form>
            </section>
          </div>

          <section id="import-preview" class="lg:sticky lg:top-6" aria-live="polite">
            <.preview result={@result} />
          </section>
        </div>
      </div>
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
        Sobald du die Antwort der KI einfügst, siehst du hier alle Fragen und was noch fehlt.
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

    assigns = assign(assigns, :uploads_needed, Enum.count(assigns.questions, &needs_upload?/1))

    ~H"""
    <div class="space-y-4">
      <div class="rounded-box border border-base-200 bg-base-100 p-6 shadow-sm">
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

      <ol id="preview-questions" class="space-y-3">
        <li
          :for={{{question, missing}, index} <- Enum.with_index(Enum.zip(@questions, @missing), 1)}
          id={"preview-question-#{index}"}
          class="rounded-box border border-base-200 bg-base-100 p-5 shadow-sm"
        >
          <div class="flex items-start gap-3">
            <span class="flex size-7 shrink-0 items-center justify-center rounded-full bg-base-200 text-xs font-bold">
              {index}
            </span>
            <div class="min-w-0 flex-1">
              <p class="text-xs font-medium uppercase tracking-wider text-base-content/45">
                {type_name(question.type)}
              </p>
              <p class="mt-0.5 font-semibold leading-snug">
                {if question.prompt in [nil, ""], do: "(ohne Fragetext)", else: question.prompt}
              </p>

              <.answers question={question} />

              <p
                :if={question.image_hint && question.type != :pin_on_image}
                class="mt-3 flex gap-2 text-sm text-base-content/60"
              >
                <.icon name="hero-photo" class="size-4 shrink-0 mt-0.5" />
                <span>Bild: {question.image_hint}</span>
              </p>

              <p
                :if={question.solution_text}
                class="mt-3 border-l-2 border-base-300 pl-3 text-sm text-base-content/60"
              >
                {question.solution_text}
              </p>

              <p
                :if={missing != []}
                class="mt-3 flex gap-2 rounded-field bg-warning/10 px-3 py-2 text-sm"
              >
                <.icon name="hero-pencil-square" class="size-4 shrink-0 mt-0.5 text-warning" />
                <span>Im Editor ergänzen: {Enum.join(missing, ", ")}</span>
              </p>
            </div>
          </div>
        </li>
      </ol>
    </div>
    """
  end

  attr :question, Question, required: true

  defp answers(%{question: %{type: type}} = assigns)
       when type in [:single_choice, :multiple_choice] do
    ~H"""
    <ul class="mt-3 space-y-1.5">
      <li
        :for={choice <- @question.data.choices}
        class={[
          "flex items-center gap-2 rounded-field px-3 py-1.5 text-sm",
          if(choice.correct, do: "bg-success/10 font-medium", else: "bg-base-200/50")
        ]}
      >
        <.icon
          name={if(choice.correct, do: "hero-check-circle-solid", else: "hero-minus-small")}
          class={[
            "size-4 shrink-0",
            if(choice.correct, do: "text-success", else: "text-base-content/30")
          ]}
        />
        {choice.text}
      </li>
    </ul>
    """
  end

  defp answers(%{question: %{type: :text_input}} = assigns) do
    ~H"""
    <p :if={@question.data.solutions != []} class="mt-3 text-sm">
      <span class="text-base-content/55">Akzeptiert:</span>
      <span :for={{solution, i} <- Enum.with_index(@question.data.solutions)} class="font-medium">
        {if i > 0, do: " · "}{solution.text}
      </span>
    </p>
    """
  end

  defp answers(%{question: %{type: :sequence}} = assigns) do
    ~H"""
    <ol class="mt-3 list-decimal space-y-1 pl-5 text-sm marker:text-base-content/40">
      <li :for={item <- @question.data.items}>{item.text}</li>
    </ol>
    """
  end

  defp answers(%{question: %{type: :matching}} = assigns) do
    ~H"""
    <ul class="mt-3 space-y-1 text-sm">
      <li :for={pair <- @question.data.pairs} class="flex items-center gap-2">
        <span>{pair.left_text}</span>
        <.icon name="hero-arrow-long-right" class="size-4 text-base-content/40" />
        <span class="font-medium">{pair.right_text}</span>
      </li>
    </ul>
    """
  end

  defp answers(%{question: %{type: :number_range, data: %{number_range: %{} = range}}} = assigns) do
    assigns = assign(assigns, :range, range)

    ~H"""
    <p class="mt-3 text-sm">
      <span class="text-base-content/55">Skala {@range.min} bis {@range.max} ·</span>
      <span class="font-medium">Lösung {@range.solution} ± {@range.tolerance}</span>
    </p>
    """
  end

  defp answers(%{question: %{type: :pin_on_image}} = assigns) do
    ~H"""
    <div class="mt-3 space-y-1 text-sm text-base-content/60">
      <p :if={@question.image_hint} class="flex gap-2">
        <.icon name="hero-photo" class="size-4 shrink-0 mt-0.5" />
        <span>Bild: {@question.image_hint}</span>
      </p>
      <p :if={@question.pin_hint} class="flex gap-2">
        <.icon name="hero-map-pin" class="size-4 shrink-0 mt-0.5" />
        <span>Pin: {@question.pin_hint}</span>
      </p>
    </div>
    """
  end

  defp answers(assigns), do: ~H""

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
       |> assign(:form, to_form(%{"text" => ""}, as: :import))
       |> assign(:result, nil)}
    end
  end

  @impl true
  def handle_event("preview", %{"import" => %{"text" => text}}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(%{"text" => text}, as: :import))
     |> assign(:result, parse(text))}
  end

  # No account yet: hand the text to GuestImportController as a regular POST.
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

  def handle_event("create", %{"import" => %{"text" => text}}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, parsed} <- parse(text),
         {:ok, game} <- Games.import_game(scope, parsed) do
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
    end
  end

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
