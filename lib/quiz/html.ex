defmodule Quiz.HTML do
  @moduledoc """
  HTML helpers for user-authored rich text.

  Question descriptions are edited with a small contenteditable editor that
  emits HTML. We never trust that HTML: it is sanitized to a tiny allowlist
  (`Quiz.HTML.DescriptionScrubber`) on write, so the database only ever holds
  safe markup and rendering with `Phoenix.HTML.raw/1` is safe.
  """

  @doc """
  Sanitizes a question description, keeping only the formatting the editor can
  produce (bold, italic, underline, line breaks, and highlight `mark`/`span`
  with a `class`). Blank input passes through unchanged.
  """
  def sanitize_description(html) when html in [nil, ""], do: html

  def sanitize_description(html) when is_binary(html) do
    HtmlSanitizeEx.Scrubber.scrub(html, Quiz.HTML.DescriptionScrubber)
  end
end
