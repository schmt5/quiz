defmodule QuizWeb.UserLive.Settings do
  use QuizWeb, :live_view

  on_mount {QuizWeb.UserAuth, :require_sudo_mode}

  alias Quiz.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <:page_header>
        <div class="mx-auto max-w-2xl">
          <div class="breadcrumbs text-xs">
            <ul>
              <li>
                <.link navigate={~p"/"} aria-label="Home">
                  <.icon name="hero-home" class="size-4" />
                </.link>
              </li>
              <li>Account</li>
            </ul>
          </div>
          <h1 class="text-2xl sm:text-3xl font-bold">Account settings</h1>
          <p class="mt-1 text-sm text-base-content/55">
            Manage your name, email address, and password.
          </p>
        </div>
      </:page_header>

      <div class="h-full overflow-y-auto">
        <div class="mx-auto max-w-2xl py-6 space-y-6">
          <section class="rounded-box border border-base-300 bg-base-100 p-6">
            <h2 class="text-lg font-bold">Profile</h2>
            <p class="mt-1 mb-4 text-sm text-base-content/55">
              The name shown alongside your quizzes.
            </p>
            <.form
              for={@name_form}
              id="name_form"
              phx-submit="update_name"
              phx-change="validate_name"
            >
              <.input
                field={@name_form[:name]}
                type="text"
                label="Name"
                autocomplete="name"
                required
              />
              <.button variant="primary" phx-disable-with="Saving..." class="mt-4">
                Update name
              </.button>
            </.form>
          </section>

          <section class="rounded-box border border-base-300 bg-base-100 p-6">
            <h2 class="text-lg font-bold">Email address</h2>
            <p class="mt-1 mb-4 text-sm text-base-content/55">
              Used to sign in. Changing it sends a confirmation link to the new address.
            </p>
            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                spellcheck="false"
                required
              />
              <.button variant="primary" phx-disable-with="Saving..." class="mt-4">
                Update email
              </.button>
            </.form>
          </section>

          <section class="rounded-box border border-base-300 bg-base-100 p-6">
            <h2 class="text-lg font-bold">Password</h2>
            <p class="mt-1 mb-4 text-sm text-base-content/55">
              Choose a strong password you don't use anywhere else.
            </p>
            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                spellcheck="false"
                value={@current_email}
              />
              <.input
                field={@password_form[:password]}
                type="password"
                label="New password"
                autocomplete="new-password"
                spellcheck="false"
                required
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
                autocomplete="new-password"
                spellcheck="false"
              />
              <.button variant="primary" phx-disable-with="Saving..." class="mt-4">
                Update password
              </.button>
            </.form>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    name_changeset = Accounts.change_user_name(user)
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:name_form, to_form(name_changeset))
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_name", %{"user" => user_params}, socket) do
    name_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, name_form: name_form)}
  end

  def handle_event("update_name", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_name(user, user_params) do
      {:ok, updated_user} ->
        name_form =
          updated_user
          |> Accounts.change_user_name()
          |> to_form()

        {:noreply,
         socket
         |> assign(:name_form, name_form)
         |> put_flash(:info, "Name updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_email(user, user_params) do
      {:ok, updated_user} ->
        email_form =
          updated_user
          |> Accounts.change_user_email(%{}, validate_unique: false)
          |> to_form()

        {:noreply,
         socket
         |> assign(:current_email, updated_user.email)
         |> assign(:email_form, email_form)
         |> put_flash(:info, "Email updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
