defmodule Quiz.Games.Question.Pin do
  @moduledoc """
  Type-specific payload for a `:pin_on_image` question.

  Holds the background image reference plus the single correct target and its
  circular tolerance radius. The target coordinates and the radius are
  normalized to `0..1`; the box is rendered at the image's natural
  `aspect_ratio` (width / height) with `object-cover`.

  Because the box matches the image's aspect ratio, `object-cover` shows the
  whole image without cropping. All views render the *identical* box, so the
  normalized coordinate space is the same everywhere and scoring is exact.

  `radius` is normalized to the box **width**. To keep the tolerance a true
  circle on screen at any aspect ratio, the vertical axis is corrected by
  `aspect_ratio`: scoring uses `sqrt(dx² + (dy / aspect_ratio)²) <= radius` and
  the rendered circle uses `height = radius * aspect_ratio` (width = `radius`).
  A square image (`aspect_ratio == 1.0`) reduces to the original behavior, so
  pins stored before this field existed load with the `1.0` default and score
  unchanged.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :image_key, :string
    field :target_x, :float
    field :target_y, :float
    field :radius, :float, default: 0.1
    field :aspect_ratio, :float, default: 1.0
  end

  @doc false
  def changeset(pin, attrs) do
    pin
    |> cast(attrs, [:image_key, :target_x, :target_y, :radius, :aspect_ratio])
    |> update_change(:target_x, &clamp/1)
    |> update_change(:target_y, &clamp/1)
    |> update_change(:radius, &clamp/1)
    |> validate_required([:image_key, :target_x, :target_y, :radius])
    |> validate_number(:radius, greater_than: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:target_x, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:target_y, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:aspect_ratio, greater_than: 0.0)
  end

  defp clamp(nil), do: nil
  defp clamp(value) when is_float(value), do: value |> max(0.0) |> min(1.0)
end
