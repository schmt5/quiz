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
          <.intro_outro_section
            legend="Intro"
            hint="Infos & Spielregeln – öffnest du als Quizmaster:in in der Lobby. Teams sehen das nie."
            text_field={@form[:intro_text]}
            upload={@uploads.intro_image}
            image_key={@intro_image_key}
            slot_name="intro"
          />

          <.intro_outro_section
            legend="Outro"
            hint="Abschluss & Verdankungen – öffnest du als Quizmaster:in am Ende des Quiz. Teams sehen das nie."
            text_field={@form[:outro_text]}
            upload={@uploads.outro_image}
            image_key={@outro_image_key}
            slot_name="outro"
          />

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

  # One authoring block for the host-only intro/outro content: an optional
  # multi-line text plus an optional image (e.g. a logo). The image slot shows
  # either the pending upload's client-side preview or the already stored image
  # with a remove action — never both, since picking a new file replaces the
  # stored one on save.
  attr :legend, :string, required: true
  attr :hint, :string, required: true
  attr :text_field, Phoenix.HTML.FormField, required: true
  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :image_key, :string, default: nil
  attr :slot_name, :string, required: true

  defp intro_outro_section(assigns) do
    ~H"""
    <fieldset class="space-y-3">
      <legend class={label_class()}>{@legend}</legend>
      <p class="text-sm text-base-content/60">{@hint}</p>

      <.input field={@text_field} type="textarea" label="Text (optional)" />

      <div class="space-y-2">
        <span class="block text-sm font-medium">Bild / Logo (optional)</span>

        <div
          :for={entry <- @upload.entries}
          class="flex items-center gap-3 rounded-field border border-base-300/70 bg-white p-3"
        >
          <.live_img_preview entry={entry} class="max-h-24 rounded-box object-contain" />
          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-upload={@upload.name}
            phx-value-ref={entry.ref}
            class="btn btn-ghost btn-sm"
          >
            <.icon name="hero-x-mark" class="size-4" /> Abbrechen
          </button>
          <p :for={err <- upload_errors(@upload, entry)} class="text-sm text-error">
            {upload_error_to_string(err)}
          </p>
        </div>

        <div
          :if={@upload.entries == [] && @image_key}
          class="flex items-center gap-3 rounded-field border border-base-300/70 bg-white p-3"
        >
          <img
            src={Quiz.Storage.url(@image_key)}
            alt=""
            class="max-h-24 rounded-box object-contain"
          />
          <button
            type="button"
            phx-click="remove_image"
            phx-value-slot={@slot_name}
            class="btn btn-ghost btn-sm"
          >
            <.icon name="hero-trash" class="size-4" /> Bild entfernen
          </button>
        </div>

        <.live_file_input upload={@upload} class="file-input w-full" />
        <p :for={err <- upload_errors(@upload)} class="text-sm text-error">
          {upload_error_to_string(err)}
        </p>
      </div>
    </fieldset>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> allow_upload(:intro_image,
       accept: ~w(.jpg .jpeg .png .webp .svg),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> allow_upload(:outro_image,
       accept: ~w(.jpg .jpeg .png .webp .svg),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    game = Games.get_game!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Quiz bearbeiten")
    |> assign(:game, game)
    |> assign(:intro_image_key, game.intro_image_key)
    |> assign(:outro_image_key, game.outro_image_key)
    |> assign(:form, to_form(Games.change_game(socket.assigns.current_scope, game)))
  end

  defp apply_action(socket, :new, _params) do
    game = %Game{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "Neues Quiz")
    |> assign(:game, game)
    |> assign(:intro_image_key, nil)
    |> assign(:outro_image_key, nil)
    |> assign(:form, to_form(Games.change_game(socket.assigns.current_scope, game)))
  end

  @impl true
  def handle_event("validate", %{"game" => game_params}, socket) do
    changeset = Games.change_game(socket.assigns.current_scope, socket.assigns.game, game_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"game" => game_params}, socket) do
    case consume_images(socket, game_params) do
      {:ok, game_params} ->
        save_game(socket, socket.assigns.live_action, game_params)

      :error ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Das Bild konnte nicht hochgeladen werden. Bitte versuch es erneut."
         )}
    end
  end

  def handle_event("remove_image", %{"slot" => "intro"}, socket) do
    {:noreply, assign(socket, :intro_image_key, nil)}
  end

  def handle_event("remove_image", %{"slot" => "outro"}, socket) do
    {:noreply, assign(socket, :outro_image_key, nil)}
  end

  def handle_event("cancel_upload", %{"upload" => upload, "ref" => ref}, socket)
      when upload in ["intro_image", "outro_image"] do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload), ref)}
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

  # Resolves both image slots into the save params: the slot assign carries the
  # currently displayed key (nil after "Bild entfernen"), a finished upload
  # replaces it. Always written, so removing an image really clears the column.
  defp consume_images(socket, params) do
    params =
      params
      |> Map.put("intro_image_key", socket.assigns.intro_image_key)
      |> Map.put("outro_image_key", socket.assigns.outro_image_key)

    with {:ok, params} <- consume_image(socket, :intro_image, "intro_image_key", params) do
      consume_image(socket, :outro_image, "outro_image_key", params)
    end
  end

  defp consume_image(socket, upload_name, field, params) do
    # Wrap the storage result in `{:ok, ...}`: consume_uploaded_entries raises
    # on anything that isn't `{:ok, _}`/`{:postpone, _}`, so a bare `{:error, _}`
    # from `Quiz.Storage.put/3` would crash the form instead of flashing.
    consumed =
      consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
        {:ok,
         Quiz.Storage.put(socket.assigns.current_scope, path,
           content_type: entry.client_type,
           filename: entry.client_name
         )}
      end)

    case consumed do
      [{:ok, key} | _] -> {:ok, Map.put(params, field, key)}
      [{:error, _reason} | _] -> :error
      [] -> {:ok, params}
    end
  end

  defp upload_error_to_string(:too_large), do: "Die Datei ist zu gross (max. 5 MB)."
  defp upload_error_to_string(:not_accepted), do: "Dieses Dateiformat wird nicht unterstützt."
  defp upload_error_to_string(_), do: "Der Upload ist fehlgeschlagen."
end
