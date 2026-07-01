defmodule QuizWeb.PlayLive.Join do
  @moduledoc """
  Participant enrollment. Reached by scanning the lobby QR code (which carries
  `?code=...`, prefilling and locking the code field) or by opening `/join`
  directly and typing the code. On success the participant's signed token is
  written to `localStorage` and they are sent to the waiting room.
  """
  use QuizWeb, :live_view

  alias Quiz.Play

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 flex items-center justify-center p-6">
      <div class="w-full max-w-sm">
        <div class="inline-flex items-baseline text-4xl font-extrabold tracking-tight">
          <span class="text-primary">Pub</span>
          <span class="bg-primary text-secondary rounded-xl px-2.5 py-0.5">Quiz</span>
        </div>

        <p class="mt-5 text-lg leading-snug text-base-content/55">
          Gebt euren Teamnamen ein{if @code_locked, do: ".", else: " und die PIN vom Quizmaster."}
        </p>

        <.form
          for={@form}
          id="join-form"
          phx-change="validate"
          phx-submit="join"
          phx-hook=".StoreToken"
          class="mt-8"
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Teamname"
            autocomplete="off"
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:code]}
            type="text"
            label="PIN"
            value={@code}
            disabled={@code_locked}
            autocomplete="off"
            inputmode="numeric"
            pattern="[0-9]*"
            maxlength="4"
            class="tracking-widest"
          />

          <div :if={@error} class="alert alert-error mt-4" role="alert">
            <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
            <span>{@error}</span>
          </div>

          <button
            type="submit"
            phx-disable-with="Anmelden …"
            class="mt-4 w-full h-14 rounded-2xl bg-primary text-secondary text-lg font-bold tracking-wide shadow-sm hover:brightness-110 active:brightness-95 transition"
          >
            Beitreten <span aria-hidden="true">→</span>
          </button>
        </.form>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".StoreToken">
        export default {
          mounted() {
            this.handleEvent("store_token", ({ key, token }) => {
              try { window.localStorage.setItem(key, token); } catch (_e) {}
            });
          },
        };
      </script>
    </div>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    code = params |> Map.get("code", "") |> String.trim() |> String.upcase()

    {:ok,
     socket
     |> assign(:page_title, "Beitreten")
     |> assign(:code, code)
     |> assign(:code_locked, code != "")
     |> assign(:error, nil)
     |> assign_form(Play.change_enrollment())}
  end

  @impl true
  def handle_event("validate", %{"participant" => params}, socket) do
    changeset = Play.change_enrollment(params) |> Map.put(:action, :validate)
    # Clear any prior join error as soon as the participant edits the form.
    {:noreply, socket |> assign(:error, nil) |> assign_form(changeset)}
  end

  def handle_event("join", %{"participant" => params}, socket) do
    # When the code field is locked we trust the assign over the (disabled) input.
    code =
      (socket.assigns.code_locked && socket.assigns.code) || Map.get(params, "code", "")

    code = code |> to_string() |> String.trim() |> String.upcase()

    with {:ok, game} <- Play.get_game_by_join_code(code),
         {:ok, _participant, token} <- Play.enroll(game, Map.get(params, "name", "")) do
      {:noreply,
       socket
       |> push_event("store_token", %{key: "quiz:#{game.join_code}", token: token})
       |> push_navigate(to: ~p"/play/#{game.join_code}")}
    else
      {:error, :not_found} ->
        message =
          if code == "" do
            "Bitte gib die PIN ein, die du vom Quizmaster bekommen hast."
          else
            "Kein Quiz mit der PIN „#{code}“ gefunden. Bitte überprüfe die PIN und versuch es nochmals."
          end

        # Unlock the (QR-prefilled) code field so the participant can actually
        # correct a stale/typo'd PIN — the message tells them to, and a disabled
        # field would otherwise leave them stuck.
        {:noreply,
         socket |> assign(:code, code) |> assign(:code_locked, false) |> assign(:error, message)}

      # The PIN is valid — the quiz just isn't accepting teams yet / anymore.
      # Keep the field as-is (editing it wouldn't help; it's the right quiz).
      {:error, :not_started} ->
        {:noreply,
         assign(
           socket,
           :error,
           "Dieses Quiz wurde noch nicht gestartet. Warte, bis die Quizmaster:in es öffnet."
         )}

      {:error, :ended} ->
        {:noreply, assign(socket, :error, "Dieses Quiz ist bereits beendet.")}

      # Fallback for the rare race where the quiz stops accepting teams between
      # the lookup and enrollment.
      {:error, :not_joinable} ->
        {:noreply, assign(socket, :error, "Dieses Quiz nimmt gerade keine neuen Teams auf.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :participant))
  end
end
