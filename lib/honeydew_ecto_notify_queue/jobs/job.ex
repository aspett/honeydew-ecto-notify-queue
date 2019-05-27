defmodule HoneydewEctoNotifyQueue.Job do
  @moduledoc "Representation of a job"

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "jobs" do
    field :queue, :string
    field :function, :string
    field :arguments, :map
    field :failure_state, :map
    field :reserved_at, :utc_datetime_usec
    field :acked_at, :utc_datetime_usec
    field :abandoned_at, :utc_datetime_usec
    field :nacked_until, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = job, attrs) do
    job
    |> cast(attrs, [:queue, :function, :arguments, :failure_state, :reserved_at, :acked_at, :nacked_until, :abandoned_at])
    |> validate_required([:queue, :function, :arguments])
  end
end
