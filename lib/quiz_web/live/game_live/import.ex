defmodule QuizWeb.GameLive.Import do
  @moduledoc """
  Creates a quiz with the author's own AI chat, as a wizard: copy the prompt,
  chat with the AI, paste its answer back. «Weiter» then creates the draft and
  opens the review of its questions (`QuizWeb.QuestionLive.Index`, `:review`).

  Nothing is sent to an AI provider from here — the round trip goes through the
  author's clipboard, so it works with any chat, free tiers included. The step
  is kept in the URL (`?schritt=`), so coming back from the chat after the
  socket reconnected lands on the same step.
  """
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.TextFormat
  alias QuizWeb.AiWizard

  @steps 1..3

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl space-y-8">
        <AiWizard.steps current={@step} />

        <section :if={@step == 1} id="ai-step-prompt" class={card_class()}>
          <AiWizard.step_heading title="Kopiere diesen Prompt">
            Damit weiss deine KI – zum Beispiel ChatGPT oder Claude –, wie sie dir beim Erstellen
            des Quiz hilft.
          </AiWizard.step_heading>

          <textarea
            id="ai-prompt"
            readonly
            rows="6"
            aria-label="Prompt für die KI"
            class="w-full resize-none rounded-field border border-base-300 bg-base-200/50 p-4 font-mono text-sm text-base-content"
          >{@prompt}</textarea>

          <.copy_button id="copy-prompt" from="ai-prompt" class="btn btn-primary btn-lg w-full">
            Prompt kopieren
          </.copy_button>

          <.step_nav next={2} />
        </section>

        <section :if={@step == 2} id="ai-step-chat" class={card_class()}>
          <AiWizard.step_heading title="Füge den Prompt in deine KI ein" />

          <ol class="space-y-4 text-lg leading-relaxed text-base-content">
            <.chat_step number={1}>
              Öffne ChatGPT, Claude oder eine andere KI und starte einen <strong>neuen Chat</strong>.
            </.chat_step>
            <.chat_step number={2}>
              Füge den Prompt ein und schicke ihn ab.
            </.chat_step>
            <.chat_step number={3}>
              Die KI fragt dich nach <strong>Thema</strong>, <strong>Zielgruppe</strong>
              und <strong>Anzahl Fragen</strong>. Passt es, schlägt sie dir auch eine Frage vor, bei
              der die Teams auf ein Bild tippen.
            </.chat_step>
            <.chat_step number={4}>
              Am Schluss zeigt sie dir das Quiz in einem Block. Kopiere ihn mit dem
              <strong>Kopieren-Knopf</strong>
              der KI und komm hierher zurück.
            </.chat_step>
          </ol>

          <.step_nav back={1} next={3} next_label="Ich habe die Antwort kopiert" />
        </section>

        <section :if={@step == 3} id="ai-step-paste" class={card_class()}>
          <AiWizard.step_heading title="Füge die Antwort der KI hier ein">
            Es macht nichts, wenn etwas Text davor oder danach mitkommt.
          </AiWizard.step_heading>

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
            class="space-y-6"
          >
            <.input
              field={@form[:text]}
              type="textarea"
              rows="10"
              phx-debounce="300"
              placeholder={placeholder()}
              class="font-mono !text-sm"
              aria-label="Antwort der KI"
            />

            <.parse_result result={@result} />

            <Layouts.guest_limit_note :if={@limit_reached} />

            <p
              :if={@anonymous or @guest}
              id="guest-notice"
              class="rounded-field bg-base-200 px-4 py-3 text-sm text-base-content"
            >
              {if @anonymous,
                do: "Ohne Konto legen wir dir einen Gastzugang an.",
                else: "Du bist als Gast unterwegs."} Deine Quizze werden nach {Quiz.Accounts.guest_lifetime_days()} Tagen gelöscht –
              <.link
                navigate={~p"/users/register"}
                class="font-semibold text-primary hover:underline"
              >
                mit einem Konto
              </.link>
              behältst du sie.
            </p>

            <div class="flex items-center justify-between gap-3">
              <.link patch={step_path(2)} class="btn btn-ghost btn-lg">
                <.icon name="hero-arrow-left" class="size-4" /> Zurück
              </.link>
              <button
                id="create-quiz"
                type="submit"
                disabled={not match?({:ok, _}, @result) or @limit_reached}
                phx-disable-with="Quiz wird erstellt …"
                class="btn btn-primary btn-lg"
              >
                Weiter zu den Fragen <.icon name="hero-arrow-right" class="size-4" />
              </button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :back, :integer, default: nil
  attr :next, :integer, required: true
  attr :next_label, :string, default: "Weiter"

  defp step_nav(assigns) do
    ~H"""
    <div class={["flex items-center gap-3", if(@back, do: "justify-between", else: "justify-end")]}>
      <.link :if={@back} id="step-back" patch={step_path(@back)} class="btn btn-ghost btn-lg">
        <.icon name="hero-arrow-left" class="size-4" /> Zurück
      </.link>
      <.link id="step-next" patch={step_path(@next)} class="btn btn-primary btn-lg">
        {@next_label} <.icon name="hero-arrow-right" class="size-4" />
      </.link>
    </div>
    """
  end

  attr :number, :integer, required: true
  slot :inner_block, required: true

  defp chat_step(assigns) do
    ~H"""
    <li class="flex gap-4">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/15 text-base font-bold text-primary">
        {@number}
      </span>
      <span class="pt-0.5">{render_slot(@inner_block)}</span>
    </li>
    """
  end

  attr :result, :any, required: true

  defp parse_result(%{result: nil} = assigns), do: ~H""

  defp parse_result(%{result: {:error, :no_questions}} = assigns) do
    ~H"""
    <div id="preview-error" class="rounded-box border border-error/40 bg-error/10 p-5">
      <p class="flex items-center gap-2 text-lg font-bold text-base-content">
        <.icon name="hero-exclamation-triangle" class="size-5 text-error" /> Keine Fragen gefunden
      </p>
      <p class="mt-2 text-base text-base-content">
        Hast du den ganzen Block der KI kopiert? Sonst bitte die KI, das Quiz nochmals vollständig
        als Block auszugeben.
      </p>
    </div>
    """
  end

  defp parse_result(%{result: {:ok, parsed}} = assigns) do
    assigns =
      assigns
      |> assign(:parsed, parsed)
      |> assign(:feedback, feedback_for_ai(parsed.warnings))

    ~H"""
    <div class="space-y-4">
      <div
        id="preview-summary"
        class="flex items-center gap-4 rounded-box border border-success/40 bg-success/10 p-5"
      >
        <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-success text-success-content">
          <.icon name="hero-check" class="size-5" />
        </span>
        <div class="min-w-0">
          <p id="preview-title" class="truncate text-lg font-bold">{@parsed.title}</p>
          <p id="preview-count" class="text-base text-base-content">
            {question_count(length(@parsed.questions))} erkannt
          </p>
        </div>
      </div>

      <div
        :if={@parsed.warnings != []}
        id="preview-warnings"
        class="rounded-box border border-warning/50 bg-warning/10 p-5"
      >
        <p class="flex items-center gap-2 font-bold">
          <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
          Nicht alles war eindeutig
        </p>
        <ul class="mt-2 list-disc space-y-1 pl-5 text-base text-base-content">
          <li :for={warning <- @parsed.warnings}>{warning}</li>
        </ul>
        <p class="mt-3 text-base text-base-content">
          Du kannst trotzdem weiter und es danach korrigieren – oder die Hinweise der KI geben:
        </p>
        <textarea id="ai-feedback" class="hidden" readonly>{@feedback}</textarea>
        <.copy_button id="copy-feedback" from="ai-feedback" class="btn btn-sm btn-soft mt-3">
          Hinweise für die KI kopieren
        </.copy_button>
      </div>
    </div>
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
       |> assign(:form, to_form(%{"text" => ""}, as: :import))
       |> assign(:result, nil)}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    step =
      case Integer.parse(params["schritt"] || "") do
        {step, ""} when step in @steps -> step
        _ -> 1
      end

    {:noreply, assign(socket, :step, step)}
  end

  @impl true
  def handle_event("preview", %{"import" => %{"text" => text} = params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :import))
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
         {:ok, game} <- Games.import_game(scope, parsed, settings_from_params(%{})) do
      {:noreply, push_navigate(socket, to: ~p"/games/#{game}/durchsicht")}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:result, parse(text))
         |> put_flash(:error, "Das Quiz konnte nicht angelegt werden. Bitte prüfe den Text.")}
    end
  end

  @doc """
  The quiz settings for `Quiz.Games.import_game/3` from the «Ablauf» step's
  params. Defaults to solutions after every question and the answer statistics
  shown, which is also what a freshly imported quiz starts with.
  """
  def settings_from_params(params) do
    %{
      review_mode: if(params["review_mode"] == "end", do: :end, else: :per_question),
      show_statistics: params["show_statistics"] != "false"
    }
  end

  defp step_path(step), do: ~p"/erstellen?#{[schritt: step]}"

  defp card_class,
    do: "space-y-8 rounded-box border border-base-200 bg-base-100 p-6 shadow-sm sm:p-8"

  defp placeholder, do: "Format: quiz-text/v1\nQuiz: …\n\nFrage: …"

  defp parse(text) do
    if String.trim(text) == "", do: nil, else: TextFormat.parse(text)
  end

  defp feedback_for_ai(warnings) do
    """
    Die Quiz-App konnte nicht alles eindeutig lesen:
    #{Enum.map_join(warnings, "\n", &("- " <> &1))}

    Bitte korrigiere das und gib das ganze Quiz nochmals in einem Codeblock im vereinbarten Format aus.
    """
  end

  defp question_count(1), do: "1 Frage"
  defp question_count(n), do: "#{n} Fragen"
end
