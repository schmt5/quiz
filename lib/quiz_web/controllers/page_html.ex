defmodule QuizWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use QuizWeb, :html

  embed_templates "page_html/*"

  @doc false
  attr :create_path, :string, required: true, doc: "where «Quiz erstellen» leads"
  attr :guest_mode, :boolean, required: true
  def landing(assigns)

  # The pieces of the landing page below are static illustrations of the app,
  # not interactive controls.

  slot :inner_block, required: true

  defp eyebrow(assigns) do
    ~H"""
    <p class="text-sm font-semibold uppercase tracking-widest text-primary/70">
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :name, :string, required: true
  attr :time, :string, required: true
  attr :bubble, :string, default: nil

  defp team_card(assigns) do
    ~H"""
    <div class="flex items-center gap-4 rounded-2xl border border-base-300/70 bg-base-100 p-4 shadow-sm sm:p-5">
      <span class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
        <.icon name="hero-user-group" class="size-6" />
      </span>
      <div class="min-w-0 flex-1">
        <p class="font-semibold">Team «{@name}»</p>
        <p class="text-sm text-base-content/60">antwortet {@time}</p>
        <p
          :if={@bubble}
          class="mt-2 inline-block rounded-2xl rounded-bl-sm bg-base-200 px-3 py-1 text-sm"
        >
          {@bubble}
        </p>
      </div>
      <div class="shrink-0 text-right">
        <p class="flex items-center justify-end gap-1 text-sm font-semibold text-success">
          <.icon name="hero-check-circle-solid" class="size-4" /> Richtig
        </p>
        <p class="text-2xl font-extrabold text-primary">+1</p>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp occasion(assigns) do
    ~H"""
    <div class="rounded-2xl border border-base-300/70 bg-base-100 p-6 transition hover:-translate-y-0.5 hover:shadow-md">
      <span class="flex size-11 items-center justify-center rounded-xl bg-secondary/40 text-primary">
        <.icon name={@icon} class="size-6" />
      </span>
      <h3 class="mt-4 font-bold">{@title}</h3>
      <p class="mt-1 text-sm text-base-content/65">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  attr :letter, :string, required: true
  attr :label, :string, required: true
  attr :percent, :integer, required: true
  attr :correct, :boolean, default: false

  defp result_bar(assigns) do
    ~H"""
    <div class={[
      "relative overflow-hidden rounded-xl border px-4 py-3",
      if(@correct, do: "border-success", else: "border-base-300/70")
    ]}>
      <div
        class={["absolute inset-y-0 left-0", if(@correct, do: "bg-success/20", else: "bg-base-200")]}
        style={"width: #{@percent}%"}
      >
      </div>
      <div class="relative flex items-center gap-3">
        <span class="flex size-7 items-center justify-center rounded-lg bg-base-100 text-sm font-bold shadow-sm">
          {@letter}
        </span>
        <span class={["flex-1", @correct && "font-semibold"]}>{@label}</span>
        <.icon :if={@correct} name="hero-check-circle-solid" class="size-5 text-success" />
        <span class="w-10 text-right text-sm font-semibold tabular-nums">{@percent} %</span>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true

  defp type_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-base-300/70 bg-base-100 p-5 transition hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-md">
      <.icon name={@icon} class="size-6 text-primary" />
      <h3 class="mt-3 font-bold">{@title}</h3>
      <p class="text-sm text-base-content/60">{@text}</p>
    </div>
    """
  end

  attr :answer, :string, required: true
  attr :teams, :integer, required: true
  attr :grade, :atom, required: true, values: [:full, :half, :zero]

  defp grading_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 rounded-xl bg-base-200/70 px-4 py-3">
      <div class="min-w-0 flex-1">
        <p class="font-semibold">{@answer}</p>
        <p class="text-xs text-base-content/55">
          {@teams} {if @teams == 1, do: "Team", else: "Teams"}
        </p>
      </div>
      <div class="flex gap-1.5" aria-hidden="true">
        <.grade_chip label="✓" active={@grade == :full} class="bg-success text-success-content" />
        <.grade_chip label="½" active={@grade == :half} class="bg-secondary text-secondary-content" />
        <.grade_chip label="✗" active={@grade == :zero} class="bg-error text-error-content" />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :class, :string, required: true

  defp grade_chip(assigns) do
    ~H"""
    <span class={[
      "flex size-9 items-center justify-center rounded-lg text-sm font-bold",
      if(@active, do: @class, else: "bg-base-100 text-base-content/35")
    ]}>
      {@label}
    </span>
    """
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp ai_step(assigns) do
    ~H"""
    <li class="rounded-2xl bg-base-100 p-6 shadow-sm">
      <span class="flex size-9 items-center justify-center rounded-full bg-primary font-bold text-primary-content">
        {@number}
      </span>
      <h3 class="mt-4 font-bold">{@title}</h3>
      <p class="mt-1 text-sm text-base-content/65">{render_slot(@inner_block)}</p>
    </li>
    """
  end
end
