defmodule QuizWeb.QuestionLive.StatsArea do
  @moduledoc """
  Presenter-facing renderers for a question's *answer distribution* — the
  anonymous "what did the room do" panel shown in the solution walkthrough
  (`QuizWeb.RunLive.Review`) when a game has `show_statistics` enabled.

  Deliberately distinct from `QuizWeb.QuestionLive.SolutionArea`: this never
  marks which answer is correct (no success/green styling), and uses the brand
  `primary` accent for a presentation feel rather than the dense, fast layout of
  the correction tool. The shapes consumed here come from `Quiz.Stats`.
  """
  use QuizWeb, :html

  attr :stats, :map, required: true

  def stats_area(%{stats: %{answered: 0}} = assigns) do
    ~H"""
    <.panel stats={@stats}>
      <p class="text-base-content/60">Noch keine Antworten.</p>
    </.panel>
    """
  end

  def stats_area(%{stats: %{type: :single_choice}} = assigns) do
    ~H"""
    <.panel stats={@stats}>
      <div class="space-y-3">
        <div :for={row <- @stats.rows} class="space-y-1">
          <div class="flex items-baseline justify-between gap-3">
            <span class="font-medium text-base-content break-words">{row.label}</span>
            <span class="shrink-0 text-base-content/60 tabular-nums">
              {row.count} · {row.pct}%
            </span>
          </div>
          <div class="h-4 rounded-full bg-base-200 overflow-hidden">
            <div
              class="h-full rounded-full bg-primary transition-all"
              style={"width: #{bar(row.count, @stats.rows)}%;"}
            >
            </div>
          </div>
        </div>
      </div>
    </.panel>
    """
  end

  def stats_area(%{stats: %{type: :text_input}} = assigns) do
    ~H"""
    <.panel stats={@stats}>
      <ul class="list-none p-0 space-y-4">
        <li :for={row <- @stats.rows} class="flex items-baseline gap-4">
          <span class="shrink-0 w-16 text-right font-display font-bold text-primary tabular-nums text-2xl">
            {row.count}×
          </span>
          <span class="font-medium text-base-content break-words">{row.label}</span>
          <span class="ml-auto shrink-0 text-base-content/50 tabular-nums">{row.pct}%</span>
        </li>
      </ul>
    </.panel>
    """
  end

  def stats_area(%{stats: %{type: :sequence}} = assigns) do
    ~H"""
    <.panel stats={@stats}>
      <ul class="list-none p-0 space-y-3">
        <li
          :for={row <- @stats.rows}
          class="flex items-center gap-3 rounded-box bg-base-200 px-3 py-2"
        >
          <span class="shrink-0 font-display font-bold text-primary tabular-nums">
            {row.count}×
          </span>
          <ol class="flex flex-wrap items-center gap-1 list-none p-0 m-0">
            <li
              :for={{label, idx} <- Enum.with_index(row.labels, 1)}
              class="inline-flex items-center gap-1 rounded-full bg-base-100 px-2 py-0.5 text-sm"
            >
              <span class="text-primary/50 tabular-nums">{idx}.</span>
              <span class="break-words">{label}</span>
            </li>
          </ol>
        </li>
      </ul>
      <p :if={@stats.more > 0} class="mt-3 text-sm text-base-content/50">
        + {@stats.more} weitere Reihenfolge(n)
      </p>
    </.panel>
    """
  end

  def stats_area(%{stats: %{type: :matching}} = assigns) do
    ~H"""
    <.panel stats={@stats}>
      <ul class="list-none p-0 space-y-4">
        <li :for={pair <- @stats.pairs} class="space-y-2">
          <p class="font-semibold text-base-content break-words">{pair.left}</p>
          <div :if={pair.rows == []} class="text-sm text-base-content/50">
            keine Antwort
          </div>
          <div :for={row <- pair.rows} class="flex items-center gap-3 pl-3">
            <span class="shrink-0 w-12 text-right text-primary font-bold tabular-nums">
              {row.count}×
            </span>
            <div class="flex-1 h-3 rounded-full bg-base-200 overflow-hidden">
              <div
                class="h-full rounded-full bg-primary"
                style={"width: #{bar(row.count, pair.rows)}%;"}
              >
              </div>
            </div>
            <span class="shrink-0 max-w-[40%] text-sm text-base-content/70 break-words">
              {row.label}
            </span>
          </div>
          <p :if={pair.more > 0} class="pl-3 text-xs text-base-content/40">
            + {pair.more} weitere
          </p>
        </li>
      </ul>
    </.panel>
    """
  end

  def stats_area(%{stats: %{type: :pin_on_image}} = assigns) do
    ~H"""
    <.panel stats={@stats}>
      <div
        class="relative w-full max-w-md overflow-hidden rounded-box bg-base-200"
        style={"aspect-ratio: #{@stats.aspect_ratio || 1.0};"}
      >
        <img
          :if={@stats.image_key}
          src={Quiz.Storage.url(@stats.image_key)}
          class="absolute inset-0 w-full h-full object-cover"
          alt="Bild"
        />
        <%!-- Every team's pin, translucent so overlaps darken into clusters. --%>
        <div
          :for={p <- @stats.points}
          class="absolute size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary/50 ring-2 ring-primary/70"
          style={"left: #{p.x * 100}%; top: #{p.y * 100}%;"}
        >
        </div>
      </div>
    </.panel>
    """
  end

  def stats_area(assigns) do
    ~H"""
    <.panel stats={@stats}>
      <p class="text-base-content/60">Für diesen Fragetyp ist keine Statistik verfügbar.</p>
    </.panel>
    """
  end

  ## Internal --------------------------------------------------------------

  attr :stats, :map, required: true
  slot :inner_block, required: true

  defp panel(assigns) do
    ~H"""
    <div class="rounded-box bg-base-100 ring-1 ring-base-300 p-5 sm:p-6 space-y-5">
      <div class="flex flex-wrap items-end gap-x-8 gap-y-3">
        <div>
          <span class="block font-display font-extrabold text-3xl leading-none tabular-nums">
            {@stats.answered}<span class="text-base-content/40 text-xl">/{@stats.total}</span>
          </span>
          <span class="text-xs text-base-content/55">Teams geantwortet</span>
        </div>
        <div :if={@stats.blank > 0}>
          <span class="block font-display font-extrabold text-3xl leading-none tabular-nums text-base-content/40">
            {@stats.blank}
          </span>
          <span class="text-xs text-base-content/55">keine Antwort</span>
        </div>
      </div>

      {render_slot(@inner_block)}

      <p class="text-xs text-base-content/45">
        Verteilung der Antworten – nicht, welche Antwort richtig ist.
      </p>
    </div>
    """
  end

  # Bar width relative to the most-picked row, so the leading answer fills the
  # track and the rest read proportionally — with a small floor so any non-zero
  # answer stays visible.
  defp bar(count, rows) do
    max = rows |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end)

    cond do
      count <= 0 -> 0
      max <= 0 -> 0
      true -> max(round(count * 100 / max), 6)
    end
  end
end
