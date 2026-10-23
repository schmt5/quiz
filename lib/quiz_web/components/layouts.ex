defmodule QuizWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QuizWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :page_header,
    doc: "optional full-width page heading rendered above the main content with a bottom border"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header
      :if={@page_header != []}
      class="h-[104px] flex items-center border-b border-base-200 px-4 sm:px-6 lg:px-8"
    >
      <div class="w-full">{render_slot(@page_header)}</div>
    </header>
    <main class={[
      "px-4 sm:px-6 lg:px-8",
      if(@page_header == [], do: "py-20", else: "h-[calc(100dvh-104px)]")
    ]}>
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  For guest accounts: when their quizzes will be deleted and how to keep them.
  Renders nothing for anyone else.
  """
  attr :current_scope, :map, default: nil
  attr :class, :any, default: nil

  def guest_banner(assigns) do
    ~H"""
    <div
      :if={@current_scope && Quiz.Accounts.guest?(@current_scope.user)}
      id="guest-banner"
      class={[
        "flex flex-wrap items-center justify-between gap-4 rounded-box border border-info/30 bg-info/5 px-4 py-3 text-sm",
        @class
      ]}
    >
      <div class="flex items-start gap-3">
        <.icon name="hero-user-circle" class="mt-0.5 size-5 shrink-0 text-info" />
        <div>
          <p class="font-semibold">Du bist als Gast unterwegs:</p>
          <ul class="mt-1 list-disc space-y-0.5 pl-5 text-base-content/75">
            <li>
              Deine Quizze werden am
              <strong>{Calendar.strftime(@current_scope.user.expires_at, "%d.%m.%Y")}</strong>
              gelöscht.
            </li>
            <li>Du kannst höchstens {Quiz.Games.guest_max_games()} Quizze erstellen.</li>
            <li>Deine Quizze sind nur in diesem Browser verfügbar.</li>
          </ul>
        </div>
      </div>
      <.link navigate={~p"/users/register"} class="btn btn-primary btn-sm">
        Konto erstellen und Quizze behalten
      </.link>
    </div>
    """
  end

  @doc """
  Shown under the (disabled) create actions once a guest holds the most quizzes
  a guest may have: registering, free of charge, lifts the limit.
  """
  attr :id, :string, default: "guest-limit"
  attr :class, :any, default: nil

  def guest_limit_note(assigns) do
    ~H"""
    <p id={@id} class={["flex items-start gap-2 text-sm text-base-content/70", @class]}>
      <.icon name="hero-lock-closed" class="mt-0.5 size-4 shrink-0 text-warning" />
      <span>
        Als Gast kannst du höchstens {Quiz.Games.guest_max_games()} Quizze erstellen.
        <.link navigate={~p"/users/register"} class="font-semibold text-primary hover:underline">
          Registriere dich kostenlos
        </.link>
        für mehr – deine Quizze bleiben erhalten.
      </span>
    </p>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
