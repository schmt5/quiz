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
          <.input
            field={@form[:show_statistics]}
            type="checkbox"
            label="Statistik in der Besprechung anzeigen"
          />
          <p class="text-sm text-base-content/60 -mt-3">
            Zeigt nach dem Quiz pro Frage, wie die Teams geantwortet haben –
            anonym und getrennt von der Musterlösung.
          </p>
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
