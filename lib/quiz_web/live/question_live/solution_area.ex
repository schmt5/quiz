defmodule QuizWeb.QuestionLive.SolutionArea do
  @moduledoc """
  Presenter-facing renderers for a question's *correct* solution. Used by the
  host's solution walkthrough (`QuizWeb.RunLive.Host`) after a quiz has finished,
  while the moderator reviews each question with the room.

  Unlike `QuizWeb.QuestionLive.AnswerArea`, these clauses are read-only and static
  (no hooks): they reveal the answer stored on `question.data` rather than letting
  anyone interact with it.
  """
  use QuizWeb, :html

  attr :question, :map, required: true

  def solution_area(%{question: %{type: :text_input, data: %{solutions: solutions}}} = assigns)
      when solutions != [] do
    ~H"""
    <div class="space-y-2">
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
        Akzeptierte Antwort(en)
      </p>
      <ul class="flex flex-wrap gap-2 list-none p-0">
        <li
          :for={solution <- @question.data.solutions}
          class="inline-flex items-center gap-2 rounded-box bg-success/10 px-3 py-2 text-success-content ring-1 ring-success/30"
        >
          <.icon name="hero-check-circle" class="size-5 text-success" />
          <span class="font-display font-bold text-base-content break-words">{solution.text}</span>
        </li>
      </ul>
    </div>
    """
  end

  def solution_area(%{question: %{type: :single_choice, data: %{choices: choices}}} = assigns)
      when choices != [] do
    ~H"""
    <ul class="space-y-2 list-none p-0">
      <li
        :for={choice <- @question.data.choices}
        class={[
          "flex items-center gap-3 rounded-box px-3 py-2 ring-1",
          (choice.correct && "bg-success/10 ring-success/40") ||
            "bg-base-200 ring-base-300 opacity-60"
        ]}
      >
        <.icon
          :if={choice.correct}
          name="hero-check-circle-solid"
          class="size-5 shrink-0 text-success"
        />
        <.icon
          :if={!choice.correct}
          name="hero-x-mark"
          class="size-5 shrink-0 text-base-content/30"
        />
        <span class={["break-words", (choice.correct && "font-bold text-base-content") || "text-base-content/70"]}>
          {choice.text}
        </span>
      </li>
    </ul>
    """
  end

  def solution_area(%{question: %{type: :sequence, data: %{items: items}}} = assigns)
      when items != [] do
    ~H"""
    <ol class="list-none p-0 space-y-2">
      <li
        :for={{item, idx} <- Enum.with_index(@question.data.items, 1)}
        class="flex items-center gap-3 rounded-box bg-base-200 px-3 py-2"
      >
        <span class="font-display font-bold text-primary/50 tabular-nums">{idx}.</span>
        <span class="font-medium text-base-content break-words">{item.text}</span>
      </li>
    </ol>
    """
  end

  def solution_area(%{question: %{type: :matching, data: %{pairs: pairs}}} = assigns)
      when pairs != [] do
    ~H"""
    <ul class="list-none p-0 space-y-2">
      <li
        :for={pair <- @question.data.pairs}
        class="flex items-center gap-2 rounded-box bg-base-200 px-3 py-2"
      >
        <span class="flex-1 min-w-0 font-semibold text-base-content break-words">
          {pair.left_text}
        </span>
        <.icon name="hero-arrow-right" class="size-4 shrink-0 text-base-content/30" />
        <span class="flex-1 min-w-0 font-medium text-success break-words">
          {pair.right_text}
        </span>
      </li>
    </ul>
    """
  end

  def solution_area(%{question: %{type: :pin_on_image, data: %{pin: pin}}} = assigns)
      when not is_nil(pin) do
    ~H"""
    <div
      class="relative w-full max-w-md overflow-hidden rounded-box bg-base-200"
      style={"aspect-ratio: #{@question.data.pin.aspect_ratio || 1.0};"}
    >
      <img
        src={Quiz.Storage.url(@question.data.pin.image_key)}
        class="absolute inset-0 w-full h-full object-cover"
        alt="Bild"
      />
      <%!-- Tolerance area: a true circle of `radius` (normalized to box width)
            centred on the target; height is scaled by the aspect ratio. --%>
      <div
        class="absolute -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-success bg-success/20"
        style={"left: #{@question.data.pin.target_x * 100}%; top: #{@question.data.pin.target_y * 100}%; width: #{@question.data.pin.radius * 200}%; height: #{@question.data.pin.radius * (@question.data.pin.aspect_ratio || 1.0) * 200}%;"}
      >
      </div>
      <%!-- Exact target point. --%>
      <div
        class="absolute size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-success ring-2 ring-white shadow"
        style={"left: #{@question.data.pin.target_x * 100}%; top: #{@question.data.pin.target_y * 100}%;"}
      >
      </div>
    </div>
    """
  end

  def solution_area(assigns) do
    ~H"""
    <p class="text-sm text-base-content/60">Keine Lösung hinterlegt.</p>
    """
  end
end
