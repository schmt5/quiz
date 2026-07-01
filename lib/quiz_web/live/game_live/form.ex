defmodule QuizWeb.GameLive.Form do
  use QuizWeb, :live_view

  alias Quiz.Games
  alias Quiz.Games.Game

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-xl space-y-6">
        <div>
          <div class="breadcrumbs text-xs">
            <ul>
              <li>
                <.link navigate={~p"/"} aria-label="Home">
                  <.icon name="hero-home" class="size-4" />
                </.link>
              </li>
              <li><.link navigate={~p"/games"}>Quizze</.link></li>
              <li>{@page_title}</li>
            </ul>
          </div>
          <h1 class="text-2xl sm:text-3xl font-bold">{@page_title}</h1>
        </div>

        <.form
          for={@form}
          id="game-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <.input
            field={@form[:title]}
            type="text"
            label="Titel"
            placeholder="z. B. Pub-Quiz Freitagabend"
          />
          <fieldset class="space-y-3">
            <legend class={label_class()}>Optionen</legend>
            <div class="grid gap-3">
              <.review_mode_option
                field={@form[:review_mode]}
                value="end"
                icon="hero-flag"
                title="Am Ende des Quiz"
                description="Du gehst die Musterlösungen nach dem Quiz am Stück durch."
              />
              <.review_mode_option
                field={@form[:review_mode]}
                value="per_question"
                icon="hero-bolt"
                title="Nach jeder Frage"
                description="Du wertest jede Frage direkt aus – ideal für Umfragen und zum gemeinsamen Besprechen."
              />
            </div>
          </fieldset>

          <label class="group flex cursor-pointer items-start gap-4 rounded-field border border-base-300/70 bg-white p-5 shadow-sm transition hover:border-primary/40 has-[:checked]:border-primary has-[:checked]:ring-4 has-[:checked]:ring-primary/15">
            <input
              type="hidden"
              name={@form[:show_statistics].name}
              value="false"
            />
            <input
              type="checkbox"
              name={@form[:show_statistics].name}
              value="true"
              checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:show_statistics].value)}
              class="peer sr-only"
            />
            <span class="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-md border-2 border-base-300 bg-white transition group-has-[:checked]:border-primary group-has-[:checked]:bg-primary">
              <.icon
                name="hero-check-mini"
                class="size-4 text-white opacity-0 transition group-has-[:checked]:opacity-100"
              />
            </span>
            <span>
              <span class="block font-bold text-primary">
                Statistik in der Besprechung anzeigen
              </span>
              <span class="mt-1 block text-sm text-base-content/60">
                Zeigt pro Frage, wie die Teams geantwortet haben –
                anonym und getrennt von der Musterlösung.
              </span>
            </span>
          </label>
          <footer class="flex items-center gap-3">
            <.button phx-disable-with="Wird gespeichert …" variant="primary">
              Quiz speichern
            </.button>
            <.button navigate={return_path(@current_scope, @return_to, @game)}>
              Abbrechen
            </.button>
          </footer>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp review_mode_option(assigns) do
    assigns = assign(assigns, :checked, to_string(assigns.field.value) == assigns.value)

    ~H"""
    <label class="group relative flex cursor-pointer items-start gap-4 rounded-field border border-base-300/70 bg-white p-5 shadow-sm transition hover:border-primary/40 has-[:checked]:border-primary has-[:checked]:ring-4 has-[:checked]:ring-primary/15">
      <input
        type="radio"
        name={@field.name}
        value={@value}
        checked={@checked}
        class="peer sr-only"
      />
      <span class="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full border-2 border-base-300 transition group-has-[:checked]:border-primary">
        <span class="size-2.5 rounded-full bg-primary opacity-0 transition group-has-[:checked]:opacity-100" />
      </span>
      <span class="flex-1">
        <span class="flex items-center gap-2 font-bold text-primary">
          <.icon
            name={@icon}
            class="size-5 text-base-content/40 transition group-has-[:checked]:text-primary"
          />
          {@title}
        </span>
        <span class="mt-1 block text-sm text-base-content/60">{@description}</span>
      </span>
    </label>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    game = Games.get_game!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Quiz bearbeiten")
    |> assign(:game, game)
    |> assign(:form, to_form(Games.change_game(socket.assigns.current_scope, game)))
  end

  defp apply_action(socket, :new, _params) do
    game = %Game{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "Neues Quiz")
    |> assign(:game, game)
    |> assign(:form, to_form(Games.change_game(socket.assigns.current_scope, game)))
  end

  @impl true
  def handle_event("validate", %{"game" => game_params}, socket) do
    changeset = Games.change_game(socket.assigns.current_scope, socket.assigns.game, game_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"game" => game_params}, socket) do
    save_game(socket, socket.assigns.live_action, game_params)
  end

  defp save_game(socket, :edit, game_params) do
    case Games.update_game(socket.assigns.current_scope, socket.assigns.game, game_params) do
      {:ok, game} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quiz aktualisiert.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, game)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_game(socket, :new, game_params) do
    case Games.create_game(socket.assigns.current_scope, game_params) do
      {:ok, game} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quiz erstellt.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, game)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _game), do: ~p"/games"
  defp return_path(_scope, "show", game), do: ~p"/games/#{game}"
end
