defmodule Quiz.Games.Question.Pin do
  @moduledoc """
  Type-specific payload for a `:pin_on_image` question.

  Holds the background image reference plus the single correct target and its
  circular tolerance radius. All coordinates and the radius are normalized to
  `0..1` relative to a 1:1 square box rendered with `object-cover`.

  Because the box is square and the image uses `object-cover`, a non-square
  source image is cropped on its longer axis. Both the editor and the
  participant view render the *identical* square box, so the visible normalized
  coordinate space is the same on both sides and scoring is exact. The only
  consequence is that the cropped-away region is unreachable — which is intended.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :image_key, :string
    field :target_x, :float
    field :target_y, :float
    field :radius, :float, default: 0.1
  end

  @doc false
  def changeset(pin, attrs) do
    pin
    |> cast(attrs, [:image_key, :target_x, :target_y, :radius])
    |> update_change(:target_x, &clamp/1)
    |> update_change(:target_y, &clamp/1)
    |> update_change(:radius, &clamp/1)
    |> validate_required([:image_key, :target_x, :target_y, :radius])
    |> validate_number(:radius, greater_than: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:target_x, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:target_y, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  defp clamp(nil), do: nil
  defp clamp(value) when is_float(value), do: value |> max(0.0) |> min(1.0)
end
