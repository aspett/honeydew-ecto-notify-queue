defmodule HoneydewEctoNotifyQueue.JobConfig do
  @moduledoc "Representation of a configuration"

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "job_configs" do
    field :key, :string
    field :value, :string

    timestamps()
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
  end

  def suspended_key, do: "suspended"
end
