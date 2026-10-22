defmodule QuizWeb.UserLive.Registration do
  use QuizWeb, :live_view

  alias Quiz.Accounts
  alias Quiz.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            {if @claim, do: "Konto erstellen und Quizze behalten", else: "Konto erstellen"}
            <:subtitle :if={@claim}>
              Deine Quizze aus dem Gastzugang bleiben erhalten und werden nicht mehr gelöscht.
            </:subtitle>
            <:subtitle :if={!@claim}>
              Schon registriert?
              <.link
                id="registration-login-link"
                navigate={~p"/users/log-in"}
                class="font-semibold text-primary hover:underline"
              >
                Jetzt anmelden
              </.link>
            </:subtitle>
          </.header>
        </div>

        <%!-- On success the form is re-submitted as a plain POST to the
             session controller (phx-trigger-action), which logs the new
             account in — a LiveView cannot write the session cookie itself. --%>
        <.form
          for={@form}
          id="registration_form"
          action={~p"/users/log-in?_action=registered"}
          method="post"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Name"
            autocomplete="name"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:email]}
            type="email"
            label="E-Mail"
            autocomplete="username"
            spellcheck="false"
            required
          />

          <.input
            field={@form[:password]}
            type="password"
            label="Passwort"
            autocomplete="new-password"
            spellcheck="false"
            required
          />

          <input type="hidden" name="user[remember_me]" value="true" />

          <.button phx-disable-with="Konto wird erstellt …" class="btn btn-primary w-full">
            Konto erstellen <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    if Accounts.guest?(user) do
      # A guest claiming its account is already signed in: saving converts the
      # account in place (no login POST), and its placeholder name and email
      # are not offered as defaults.
      changeset = Accounts.change_user_registration(%User{}, %{}, validate_unique: false)

      {:ok,
       socket
       |> assign(claim: true, trigger_submit: false)
       |> assign_form(changeset), temporary_assigns: [form: nil]}
    else
      {:ok, redirect(socket, to: QuizWeb.UserAuth.signed_in_path(socket))}
    end
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{}, %{}, validate_unique: false)

    {:ok,
     socket
     |> assign(claim: false, trigger_submit: false)
     |> assign_form(changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, %{assigns: %{claim: true}} = socket) do
    case Accounts.claim_guest(socket.assigns.current_scope.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Dein Konto ist erstellt. Deine Quizze bleiben erhalten.")
         |> redirect(to: ~p"/games")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
