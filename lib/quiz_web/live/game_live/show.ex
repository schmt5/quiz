defmodule QuizWeb.GameLive.Show do
  use QuizWeb, :live_view

  alias Quiz.Games

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
              <li>{@game.title}</li>
            </ul>
          </div>
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-2">
              <div class="tooltip tooltip-right" data-tip="Zurück zu den Quizzen">
                <.link
                  navigate={~p"/games"}
                  class="btn btn-ghost btn-sm btn-square"
                  aria-label="Zurück zu den Quizzen"
                >
                  <.icon name="hero-arrow-left" class="size-4" />
                </.link>
              </div>
              <h1 class="text-2xl font-bold">{@game.title}</h1>
            </div>
            <div class="flex items-center gap-2">
              <.link
                :if={@questions != [] and @game.status in [:open, :running]}
                navigate={~p"/games/#{@game}/run"}
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-arrow-right" class="size-4" /> Zur Durchführung
              </.link>
              <button
                :if={@questions != [] and @game.status in [:draft, :closed]}
                type="button"
                phx-click="open_run"
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-play" class="size-4" /> Durchführung eröffnen
              </button>
              <.link
                :if={@game.status in [:running, :finished, :closed]}
                navigate={~p"/games/#{@game}/correction"}
                class="btn btn-soft btn-sm"
              >
                <.icon name="hero-check-circle" class="size-4" /> Korrigieren
              </.link>
              <.link
                :if={@game.status in [:running, :finished, :closed]}
                navigate={~p"/games/#{@game}/leaderboard"}
                class="btn btn-soft btn-sm"
              >
                <.icon name="hero-trophy" class="size-4" /> Rangliste
              </.link>
              <button
                type="button"
                popovertarget="game-actions"
                class="btn btn-soft btn-sm btn-square"
                style="anchor-name:--game-actions"
                aria-label="Weitere Aktionen"
              >
                <.icon name="hero-ellipsis-vertical" class="size-5" />
              </button>
            </div>
            <ul
              class="dropdown dropdown-end menu w-52 rounded-box bg-base-100 shadow-sm"
              popover
              id="game-actions"
              style="position-anchor:--game-actions"
            >
              <li>
                <.link navigate={~p"/games/#{@game}/edit?return_to=show"}>
                  <.icon name="hero-pencil-square" class="size-5" /> Quiz bearbeiten
                </.link>
              </li>
              <li>
                <button type="button" phx-click="duplicate">
                  <.icon name="hero-document-duplicate" class="size-5" /> Quiz duplizieren
                </button>
              </li>
              <li>
                <.copy_button id="copy-quiz-text" from="quiz-text" icon="hero-document-text">
                  Als Text kopieren
                </.copy_button>
              </li>
            </ul>
            <%!-- The export for "Als Text kopieren": the quiz in the AI text format
                 (images survive only as their hints). --%>
            <textarea id="quiz-text" class="hidden" readonly>{Quiz.Games.TextFormat.render(@game, @questions)}</textarea>
          </div>
        </div>
      </:page_header>

      <div class="mx-auto max-w-7xl py-6">
        <Layouts.guest_banner current_scope={@current_scope} class="mb-6" />
        <div
          :if={@incomplete_questions != []}
          id="incomplete-confirm"
          class="mb-6 rounded-box border border-warning/40 bg-warning/10 p-5"
        >
          <h3 class="flex items-center gap-2 font-bold">
            <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
            {incomplete_title(length(@incomplete_questions))}
          </h3>
          <ul class="mt-3 space-y-2 text-sm">
            <li :for={question <- @incomplete_questions}>
              <.link
                navigate={~p"/games/#{@game}/questions/#{question}/edit"}
                class="font-medium hover:underline"
              >
                {question_label(question)}
              </.link>
              <span class="text-base-content/60">
                – es fehlt {Enum.join(Quiz.Games.Question.missing_requirements(question), ", ")}
              </span>
            </li>
          </ul>

          <%= if length(@incomplete_questions) < length(@questions) do %>
            <p class="mt-4 text-sm text-base-content/70">
              Du kannst trotzdem eröffnen – diese Fragen werden dann in der Durchführung
              übersprungen. Beim nächsten Eröffnen sind sie wieder dabei, sobald sie fertig sind.
            </p>
            <div class="mt-4 flex flex-wrap gap-2">
              <button
                id="open-run-skipping"
                type="button"
                phx-click="open_run_skipping"
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-play" class="size-4" /> Ohne diese eröffnen
              </button>
              <button type="button" phx-click="dismiss_incomplete" class="btn btn-ghost btn-sm">
                Abbrechen
              </button>
            </div>
          <% else %>
            <p class="mt-4 text-sm text-base-content/70">
              Noch keine Frage ist spielbereit. Ergänze zuerst mindestens eine, dann kannst du
              eröffnen.
            </p>
            <button
              type="button"
              phx-click="dismiss_incomplete"
              class="btn btn-ghost btn-sm mt-3"
            >
              Schliessen
            </button>
          <% end %>
        </div>

        <div class="rounded-box bg-base-200 p-6">
          <div class="flex items-center justify-between gap-4 pb-4 border-b border-base-300">
            <h3 class="text-lg font-bold text-base-content">
              Fragen ({length(@questions)})
            </h3>
            <.link
              navigate={~p"/games/#{@game}/questions"}
              class="btn btn-primary"
            >
              <.icon name="hero-clipboard-document-list" /> Fragen verwalten
            </.link>
          </div>

          <div
            :if={@missing_images != []}
            id="missing-images"
            class="mt-4 flex items-start gap-3 rounded-box border border-info/30 bg-info/5 p-4 text-sm"
          >
            <.icon name="hero-photo" class="mt-0.5 size-5 shrink-0 text-info" />
            <div>
              <p class="font-semibold">{missing_images_label(length(@missing_images))}</p>
              <p class="mt-0.5 text-base-content/70">
                Diese Fragen brauchen noch ein Bild. Öffne sie, um es hochzuladen.
              </p>
            </div>
          </div>

          <div
            :if={@questions == []}
            class="mt-6 rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
          >
            Noch keine Fragen — verwalte dein Quiz, um die erste hinzuzufügen.
          </div>

          <ul :if={@questions != []} id="questions" class="mt-4 space-y-1">
            <li
              :for={{question, idx} <- Enum.with_index(@questions)}
              id={"question-#{question.id}"}
            >
              <.link
                navigate={~p"/games/#{@game}/questions/#{question}/edit"}
                class="block rounded-md px-3 py-2 border border-transparent hover:bg-base-300/60 transition"
              >
                <div class="flex items-baseline gap-3">
                  <span class="font-mono text-xs text-base-content/60 w-8 shrink-0">
                    {pad(idx + 1)}
                  </span>
                  <span class="font-mono text-xs uppercase tracking-wider text-base-content/60 w-32 shrink-0">
                    {humanize_type(question.type)}
                  </span>
                  <span class="truncate text-sm">{question.prompt}</span>
                  <span
                    :if={question.skipped}
                    class="ml-auto inline-flex shrink-0 items-center gap-1 self-center text-xs font-medium text-warning"
                  >
                    <.icon name="hero-forward" class="size-4" /> Wird übersprungen
                  </span>
                  <span
                    :if={question.id in @missing_images}
                    class="ml-auto inline-flex shrink-0 items-center gap-1 self-center text-xs font-medium text-info"
                  >
                    <.icon name="hero-photo" class="size-4" /> Bild fehlt
                  </span>
                </div>
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    game = Games.get_game!(socket.assigns.current_scope, id)

    if connected?(socket) do
      Games.subscribe_games(socket.assigns.current_scope)
      Games.subscribe_questions(socket.assigns.current_scope)
      # Runtime status transitions (open/start/advance/finish) are broadcast on
      # the run topic, not the Games user topic. Without this, @game.status goes
      # stale and the status-gated action buttons (e.g. "Durchführung eröffnen")
      # keep showing — letting a click regress a live :running row back to :open.
      Quiz.Play.subscribe(game)
    end

    {:ok,
     socket
     |> assign(:page_title, game.title)
     |> assign(:game, game)
     |> assign(:incomplete_questions, [])
     |> assign_questions(Games.list_questions_for_game(socket.assigns.current_scope, game))}
  end

  defp assign_questions(socket, questions) do
    socket
    |> assign(:questions, questions)
    |> assign(
      :missing_images,
      for(question <- questions, Quiz.Games.Question.image_missing?(question), do: question.id)
    )
  end

  defp missing_images_label(1), do: "1 Bild fehlt noch"
  defp missing_images_label(n), do: "#{n} Bilder fehlen noch"

  @impl true
  def handle_event("duplicate", _params, socket) do
    case Games.duplicate_game(socket.assigns.current_scope, socket.assigns.game) do
      {:ok, copy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quiz dupliziert.")
         |> push_navigate(to: ~p"/games/#{copy}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Quiz konnte nicht dupliziert werden.")}
    end
  end

  def handle_event("open_run", _params, socket), do: open_run(socket, [])

  def handle_event("open_run_skipping", _params, socket),
    do: open_run(socket, skip_incomplete: true)

  def handle_event("dismiss_incomplete", _params, socket),
    do: {:noreply, assign(socket, :incomplete_questions, [])}

  defp open_run(socket, opts) do
    case Quiz.Play.open_run(socket.assigns.current_scope, socket.assigns.game, opts) do
      {:ok, game} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{game}/run")}

      {:error, {:incomplete_questions, questions}} ->
        {:noreply, assign(socket, :incomplete_questions, questions)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Durchführung konnte nicht eröffnet werden.")}
    end
  end

  defp question_label(%{prompt: prompt, position: position}) when prompt in [nil, ""],
    do: "Frage #{position} (ohne Fragetext)"

  defp question_label(%{prompt: prompt}), do: prompt

  defp incomplete_title(1), do: "1 Frage ist noch nicht fertig"
  defp incomplete_title(n), do: "#{n} Fragen sind noch nicht fertig"

  @impl true
  def handle_info(
        {:updated, %Quiz.Games.Game{id: id} = game},
        %{assigns: %{game: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :game, game)}
  end

  def handle_info(
        {:deleted, %Quiz.Games.Game{id: id}},
        %{assigns: %{game: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "Das aktuelle Quiz wurde gelöscht.")
     |> push_navigate(to: ~p"/games")}
  end

  def handle_info({type, %Quiz.Games.Game{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info({type, %Quiz.Games.Question{game_id: game_id}}, socket)
      when type in [:created, :updated, :deleted] do
    if game_id == socket.assigns.game.id do
      questions =
        Games.list_questions_for_game(socket.assigns.current_scope, socket.assigns.game)

      {:noreply, assign_questions(socket, questions)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reordered, %Quiz.Games.Game{id: id}}, socket) do
    if id == socket.assigns.game.id do
      questions =
        Games.list_questions_for_game(socket.assigns.current_scope, socket.assigns.game)

      {:noreply, assign_questions(socket, questions)}
    else
      {:noreply, socket}
    end
  end

  # Runtime status/grading broadcasts from the run topic keep the status-gated
  # action buttons in sync with the live run.
  def handle_info(
        {:status_changed, %Quiz.Games.Game{id: id} = game},
        %{assigns: %{game: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :game, game)}
  end

  def handle_info(
        {:grading_published, %Quiz.Games.Game{id: id} = game, _leaderboard},
        %{assigns: %{game: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :game, game)}
  end

  # Other run-topic broadcasts (participant_joined, answer_submitted, …) don't
  # affect this screen; ignore them so they can never crash the LiveView.
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp humanize_type(:single_choice), do: "Single-Choice"
  defp humanize_type(:multiple_choice), do: "Multiple-Choice"
  defp humanize_type(:text_input), do: "Texteingabe"
  defp humanize_type(:sequence), do: "Reihenfolge"
  defp humanize_type(:number_range), do: "Zahlenschätzung"
  defp humanize_type(:pin_on_image), do: "Pin auf Bild"
  defp humanize_type(:matching), do: "Zuordnung"
  defp humanize_type(other), do: to_string(other)
end
