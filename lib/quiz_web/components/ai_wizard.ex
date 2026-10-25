defmodule QuizWeb.AiWizard do
  @moduledoc """
  The step indicator of «Quiz mit KI erstellen»: the first three steps live in
  `QuizWeb.GameLive.Import`, the review of the questions and the run settings in
  `QuizWeb.QuestionLive.Index` (`:review`), once the draft exists.
  """
  use QuizWeb, :html

  @steps ["Prompt kopieren", "Mit der KI chatten", "Antwort einfügen", "Fragen prüfen", "Ablauf"]

  @doc "The number of steps in the wizard."
  def step_count, do: length(@steps)

  attr :current, :integer, required: true, doc: "1-based"

  def steps(assigns) do
    assigns = assign(assigns, :steps, Enum.with_index(@steps, 1))

    ~H"""
    <ol id="wizard-steps" class="flex items-center gap-2" aria-label="Schritte">
      <li
        :for={{label, number} <- @steps}
        aria-current={number == @current && "step"}
        class={["flex items-center gap-2", number == @current && "min-w-0 flex-1"]}
      >
        <span class={[
          "flex size-8 shrink-0 items-center justify-center rounded-full text-sm font-bold transition",
          number < @current && "bg-primary/15 text-primary",
          number == @current && "bg-primary text-primary-content shadow-sm",
          number > @current && "bg-base-200 text-base-content/50"
        ]}>
          <.icon :if={number < @current} name="hero-check" class="size-4" />
          <span :if={number >= @current}>{number}</span>
        </span>
        <span :if={number == @current} class="truncate text-sm font-semibold">{label}</span>
        <span :if={number != @current} class="sr-only">{label}</span>
        <span
          :if={number < length(@steps)}
          class={[
            "h-0.5 w-4 shrink-0 rounded-full sm:w-8",
            if(number < @current, do: "bg-primary/40", else: "bg-base-300")
          ]}
          aria-hidden="true"
        >
        </span>
      </li>
    </ol>
    """
  end

  @doc "The heading and lead text of a step, large and in full contrast so it gets read."
  attr :title, :string, required: true
  slot :inner_block

  def step_heading(assigns) do
    ~H"""
    <div class="space-y-3">
      <h1 class="text-2xl font-bold leading-tight sm:text-3xl">{@title}</h1>
      <div :if={@inner_block != []} class="text-lg leading-relaxed text-base-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc "A large radio choice with an icon, as used for the run settings."
  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, required: true
  attr :value, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :recommended, :boolean, default: false
  slot :inner_block, required: true

  def option_card(assigns) do
    ~H"""
    <label
      for={@id}
      class="group relative flex cursor-pointer flex-col gap-2 rounded-box border-2 border-base-300 bg-base-100 p-4 transition hover:border-primary/40 has-checked:border-primary has-checked:bg-primary/5"
    >
      <input
        id={@id}
        type="radio"
        name={@field.name}
        value={@value}
        checked={to_string(@field.value) == @value}
        class="sr-only"
      />
      <div class="flex items-center gap-2">
        <span class="flex size-10 items-center justify-center rounded-xl bg-base-200 text-base-content/70 transition group-has-checked:bg-primary group-has-checked:text-primary-content">
          <.icon name={@icon} class="size-5" />
        </span>
        <span :if={@recommended} class="badge badge-soft badge-primary badge-sm">Empfohlen</span>
        <.icon
          name="hero-check-circle-solid"
          class="ml-auto size-6 text-primary opacity-0 transition group-has-checked:opacity-100"
        />
      </div>
      <span class="text-lg font-semibold">{@title}</span>
      <span class="text-base text-base-content/80">{render_slot(@inner_block)}</span>
    </label>
    """
  end
end
