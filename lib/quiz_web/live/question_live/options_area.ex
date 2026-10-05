defmodule QuizWeb.QuestionLive.OptionsArea do
  @moduledoc """
  Presenter-facing, read-only mirror of what participants see on their phones
  while answering — shown in the "Antworten" tab of the host sidebar
  (`QuizWeb.RunLive.Host`), so the moderator can read out the options.

  The host screen is projected, so while answers are being collected nothing
  here may give the solution away: no correct marks, sequence items and matching
  values shuffled away from their authored (= solution) order. Only once the
  question is `revealing` are the correct choice options highlighted.

  Unlike `QuizWeb.QuestionLive.AnswerArea`, these clauses are static: no hooks,
  no form fields.
  """
  use QuizWeb, :html

  alias QuizWeb.QuestionLive.AnswerArea

  @doc """
  Prepares `question` for the preview: shuffles sequence items and the matching
  value pool once, so the host can keep the result in an assign and the order
  stays put across re-renders of the same question.
  """
  def prepare(question) do
    %{question: AnswerArea.prepare_question(question), pool: pool(question)}
  end

  defp pool(%{type: :matching, data: %{pairs: pairs}}) do
    pairs |> Enum.map(& &1.right_text) |> shuffle_away()
  end

  defp pool(_question), do: []

  # Shuffles `list` into an order different from the given one whenever such an
  # order exists, so the pool never lines up with the left column 1:1.
  defp shuffle_away(list) do
    if list |> Enum.uniq() |> length() > 1 do
      Stream.repeatedly(fn -> Enum.shuffle(list) end) |> Enum.find(&(&1 != list))
    else
      list
    end
  end

  attr :options, :map, required: true, doc: "the result of `prepare/1`"
  attr :revealing, :boolean, default: false

  def options_area(assigns) do
    assigns = assign(assigns, :question, assigns.options.question)

    ~H"""
    <div id="options-preview" class="space-y-4">
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-base-content/45">
        {hint(@question.type)}
      </p>
      <.options question={@question} pool={@options.pool} revealing={@revealing} />
    </div>
    """
  end

  attr :question, :map, required: true
  attr :pool, :list, required: true
  attr :revealing, :boolean, required: true

  defp options(%{question: %{type: type, data: %{choices: [_ | _]}}} = assigns)
       when type in [:single_choice, :multiple_choice] do
    # The ids carry the question id so the next question renders fresh rows
    # instead of morphing the previous ones — otherwise the reveal styling
    # would fade out visibly on the projector, on the new question's options.
    ~H"""
    <ul class="space-y-2 list-none p-0">
      <li
        :for={{choice, idx} <- Enum.with_index(@question.data.choices)}
        id={"option-#{@question.id}-#{idx}"}
        class={[
          "flex items-center gap-3 rounded-box px-3 py-2.5 ring-1 transition duration-300 motion-reduce:transition-none",
          cond do
            !@revealing -> "bg-base-100 ring-base-300"
            choice.correct -> "bg-success/10 ring-success/40"
            true -> "bg-base-100 ring-base-300 opacity-50"
          end
        ]}
      >
        <.choice_letter
          index={idx}
          class={@revealing && choice.correct && "bg-success/20 text-success"}
        />
        <span class={[
          "min-w-0 flex-1 text-base break-words",
          (@revealing && choice.correct && "font-bold") || "font-medium"
        ]}>
          {choice.text}
        </span>
        <.icon
          :if={@revealing && choice.correct}
          name="hero-check-circle-solid"
          class="size-5 shrink-0 text-success"
        />
      </li>
    </ul>
    """
  end

  defp options(%{question: %{type: :sequence, data: %{items: [_ | _]}}} = assigns) do
    ~H"""
    <ul class="space-y-2 list-none p-0">
      <li
        :for={item <- @question.data.items}
        class="flex items-center gap-3 rounded-box bg-base-100 px-3 py-2.5 ring-1 ring-base-300"
      >
        <.icon name="hero-arrows-up-down" class="size-4 shrink-0 text-base-content/40" />
        <span class="min-w-0 font-medium break-words">{item.text}</span>
      </li>
    </ul>
    """
  end

  defp options(%{question: %{type: :matching, data: %{pairs: [_ | _]}}} = assigns) do
    ~H"""
    <ul class="space-y-2.5 list-none p-0">
      <li :for={pair <- @question.data.pairs} class="flex flex-col gap-1">
        <span class="text-sm font-semibold break-words">{pair.left_text}</span>
        <span class="h-9 rounded-box border-2 border-dashed border-base-300"></span>
      </li>
    </ul>
    <div class="flex flex-wrap gap-2 rounded-box bg-base-100/70 p-3">
      <span
        :for={value <- @pool}
        class="rounded-box border border-base-300 bg-base-100 px-3 py-1.5 text-sm font-medium shadow-sm"
      >
        {value}
      </span>
    </div>
    """
  end

  defp options(%{question: %{type: :pin_on_image, data: %{pin: %{} = pin}}} = assigns) do
    assigns = assign(assigns, :pin, pin)

    ~H"""
    <div
      class="relative w-full overflow-hidden rounded-box bg-base-300"
      style={"aspect-ratio: #{@pin.aspect_ratio || 1.0};"}
    >
      <img
        src={Quiz.Storage.url(@pin.image_key)}
        class="absolute inset-0 w-full h-full object-cover"
        alt="Bild, auf dem die Teams einen Pin setzen"
      />
    </div>
    """
  end

  defp options(%{question: %{type: :number_range, data: %{number_range: %{} = nr}}} = assigns) do
    assigns = assign(assigns, :nr, nr)

    ~H"""
    <.field_mock placeholder="Zahl eingeben …" />
    <p class="text-sm text-base-content/60">
      Schätze zwischen <span class="font-semibold text-base-content tabular-nums">{@nr.min}</span>
      und <span class="font-semibold text-base-content tabular-nums">{@nr.max}</span>
    </p>
    """
  end

  defp options(%{question: %{type: :text_input}} = assigns) do
    ~H"""
    <.field_mock placeholder="Antwort eintippen …" />
    """
  end

  defp options(assigns) do
    ~H"""
    <p class="text-sm text-base-content/60">Keine Antwortmöglichkeiten hinterlegt.</p>
    """
  end

  # A static stand-in for the participant's input field — looks like one, but
  # there is nothing to type into.
  attr :placeholder, :string, required: true

  defp field_mock(assigns) do
    ~H"""
    <div class="flex h-12 items-center rounded-box border border-base-300 bg-base-100 px-4 text-base-content/40">
      {@placeholder}
    </div>
    """
  end

  defp hint(:single_choice), do: "Eine Antwort wählen"
  defp hint(:multiple_choice), do: "Mehrere Antworten möglich"
  defp hint(:text_input), do: "Freitext-Antwort"
  defp hint(:sequence), do: "In die richtige Reihenfolge bringen"
  defp hint(:matching), do: "Paare zuordnen"
  defp hint(:pin_on_image), do: "Pin auf dem Bild setzen"
  defp hint(:number_range), do: "Zahl schätzen"
  defp hint(_type), do: "Antwort"
end
