defmodule QuizWeb.LeaderboardComponent do
  @moduledoc """
  Shared rendering for final standings, reused by the corrector/presenter
  `LeaderboardLive.Show` and the participants' finish screen in `PlayLive.Play`.
  """
  use QuizWeb, :html

  @doc """
  Renders a ranked standings table. `rows` is the output of
  `Quiz.Play.leaderboard/1`: `%{participant, score, rank}`. `highlight_id`
  optionally emphasises one participant (the current team).
  """
  attr :rows, :list, required: true
  attr :highlight_id, :any, default: nil

  def standings(assigns) do
    ~H"""
    <ol class="space-y-2 list-none p-0">
      <li
        :for={row <- @rows}
        class={[
          "flex items-center gap-3 rounded-box px-4 py-3 ring-1",
          (row.participant.id == @highlight_id && "bg-primary/10 ring-primary") ||
            "bg-base-100 ring-base-300"
        ]}
      >
        <span class={[
          "grid size-9 shrink-0 place-items-center rounded-full font-display font-extrabold tabular-nums",
          rank_class(row.rank)
        ]}>
          {row.rank}
        </span>
        <span class="flex-1 min-w-0 font-semibold truncate">{row.participant.name}</span>
        <span class="font-display text-xl font-extrabold tabular-nums text-primary">
          {format_score(row.score)}
        </span>
      </li>
    </ol>
    """
  end

  defp rank_class(1), do: "bg-warning text-warning-content"
  defp rank_class(2), do: "bg-base-300 text-base-content"
  defp rank_class(3), do: "bg-amber-700/80 text-white"
  defp rank_class(_), do: "bg-base-200 text-base-content/60"

  @doc "Formats a half-point score as a compact string (2, 1.5, …)."
  def format_score(score) do
    if score == Float.round(score) and score == trunc(score) do
      Integer.to_string(trunc(score))
    else
      :erlang.float_to_binary(score * 1.0, decimals: 1)
    end
  end
end
