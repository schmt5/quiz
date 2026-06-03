defmodule Quiz.HTML.DescriptionScrubber do
  @moduledoc """
  Allowlist scrubber for question descriptions. Permits only the inline
  formatting the rich-text editor produces and strips everything else
  (scripts, event handlers, inline styles, links, etc.).
  """

  use HtmlSanitizeEx

  remove_cdata_sections_before_scrub()
  strip_comments()

  allow_tag_with_these_attributes("strong", [])
  allow_tag_with_these_attributes("b", [])
  allow_tag_with_these_attributes("em", [])
  allow_tag_with_these_attributes("i", [])
  allow_tag_with_these_attributes("u", [])
  allow_tag_with_these_attributes("br", [])
  allow_tag_with_these_attributes("p", [])

  # Highlights are emitted as <mark class="hl-..."> (and <span> for pasted
  # variants). The class allowlist itself is enforced by the editor; here we
  # just keep the attribute and drop everything dangerous.
  allow_tag_with_these_attributes("mark", ["class"])
  allow_tag_with_these_attributes("span", ["class"])
end
