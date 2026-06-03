defmodule Quiz.Play.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "participants" do
    field :name, :string
    field :game_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:name, :game_id])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :game_id])
    |> validate_length(:name, min: 1, max: 50)
    |> unique_constraint(:name,
      name: :participants_game_id_name_index,
      message: "ist bereits vergeben"
    )
  end
end
