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

    embeds_one :queue_info, QueueInfo, primary_key: false do
      field :from, :map
    end

    field :reserved_at, :naive_datetime
    field :acked_at, :naive_datetime
    field :abandoned_at, :naive_datetime
    field :nacked_until, :naive_datetime

    timestamps()
  end

  def changeset(%__MODULE__{} = job, attrs) do
    job
    |> cast(attrs, [:queue, :function, :arguments, :failure_state, :reserved_at, :acked_at, :nacked_until, :abandoned_at])
    |> cast_embed(:queue_info, required: true, with: &queue_info_changeset/2)
    |> validate_required([:queue, :function, :arguments])
  end

  def queue_info_changeset(%__MODULE__.QueueInfo{} = queue_info, attrs) do
    queue_info
    |> cast(attrs, [:from])
  end
end
