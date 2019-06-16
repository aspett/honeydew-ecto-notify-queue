defmodule HoneydewEctoNotifyQueue do
  @moduledoc """
  This is a FIFO ecto database implementation of the honeydew queue
  Started with `Honeydew.queue_spec/2`.
  """

  @behaviour Honeydew.Queue

  import Ecto.Query, only: [from: 2]

  require Logger

  alias HoneydewEctoNotifyQueue.{Job, JobConfig}

  @config_channel "job_configs"
  @doc false
  def config_channel, do: @config_channel

  @jobs_channel "jobs"
  @doc false
  def jobs_channel, do: @jobs_channel

  defmodule QState do
    defstruct [
      :repo,
      :queue_name,
      :max_job_time,
      :retry_seconds,
      :config_notification_ref,
      :jobs_notification_ref,
      :database_suspended,
      quiet_locking_errors: false,
      per_queue_suspension: false
    ]
  end

  @impl true
  @spec init(String.t(), list()) :: {:ok, %QState{}}
  def init(queue_name, opts) when is_list(opts) do
    allowed_opts_map =
      opts
      |> Map.new()      
      |> Map.take([
        :repo,
        :max_job_time,
        :retry_seconds,
        :notifier,
        :quiet_locking_errors,
        :per_queue_suspension
      ])

    %{repo: _, max_job_time: _, retry_seconds: _, notifier: _} = allowed_opts_map

    do_init(queue_name, allowed_opts_map)
  end

  @spec do_init(String.t(), map()) :: {:ok, %QState{}}
  defp do_init(queue_name, %{notifier: notifier} = opts) do
    {:ok, config_notification_ref} = start_config_notifier(notifier)
    {:ok, jobs_notification_ref} = start_jobs_notifier(notifier)

    state =
      %QState{}
      |> Map.merge(opts)
      |> Map.merge(%{
        queue_name: queue_name,
        config_notification_ref: config_notification_ref,
        jobs_notification_ref: jobs_notification_ref
      })
      |> refresh_config()

    {:ok, state}
  end

  defp start_config_notifier(notifier) do
    pid = Process.whereis(notifier)
    Postgrex.Notifications.listen(pid, @config_channel)
  end

  defp start_jobs_notifier(notifier) do
    pid = Process.whereis(notifier)
    Postgrex.Notifications.listen(pid, @jobs_channel)
  end

  @impl true
  @doc "Adds a job to the jobs table"
  def enqueue(job, %QState{repo: repo} = state) do
    debug_log("ENQUEUE")

    attrs = serialize(job, state)

    db_job = Job.changeset(%Job{}, attrs)
    db_job = repo.insert!(db_job)

    {state, %{job | private: db_job.id}}
  end

  @impl true
  @doc """
  Will retrieve the first job which is unreserved, or was reserved but considered stale
  A job is assumed stale when it is still in the jobs table after the specified max job time
  """
  def reserve(%QState{database_suspended: true} = state) do
    debug_log("RESERVE attempted; but queue suspended")
    {:empty, state}
  end

  def reserve(%QState{repo: repo} = state) do
    debug_log("RESERVE")
    now = DateTime.utc_now()

    query =
      from(
        j in Job,
        where:
          is_nil(j.reserved_at) or
            fragment("EXTRACT(EPOCH FROM (? - ?))", ^now, j.reserved_at) >= ^state.max_job_time,
        where: is_nil(j.acked_at),
        where: is_nil(j.nacked_until) or j.nacked_until <= ^now,
        where: j.queue == ^to_string(state.queue_name),
        limit: 1,
        order_by: [asc: j.inserted_at],
        lock: "FOR UPDATE NOWAIT"
      )

    {:ok, job} =
      repo.transaction(fn ->
        case repo.one(query) do
          nil ->
            nil

          job ->
            job =
              job
              |> Job.changeset(%{reserved_at: DateTime.utc_now()})
              |> repo.update!()

            job
        end
      end)

    case job do
      nil ->
        {:empty, state}

      job ->
        job = deserialize(job)
        debug_log("Picking up job: " <> inspect(job))

        {job, state}
    end
  rescue
    error ->
      case error do
        %Postgrex.Error{postgres: %{code: :lock_not_available}} ->
          unless state.quiet_locking_errors, do: Logger.error(inspect(error))

        _ ->
          Logger.error(inspect(error))
      end

      {:empty, state}
  end

  #
  # Ack/Nack
  #

  @impl true
  @doc """
  Acknowledges the completion of the job, deleting it from the jobs table
  """
  def ack(%Honeydew.Job{private: id, failure_private: failure}, %QState{repo: repo} = state) do
    debug_log("ACK JOB")

    repo.transaction(fn ->
      query =
        from(
          j in Job,
          where: j.id == ^id,
          where: j.queue == ^to_string(state.queue_name),
          limit: 1,
          lock: "FOR UPDATE"
        )

      job = repo.one(query)

      updates = %{acked_at: DateTime.utc_now(), reserved_at: nil}

      # Adds support for a failure mode which passes along an
      # abandoned_at date. The existing AbandonFailureMode simply 'acks'
      # the job with no further information.

      updates =
        case failure do
          %{abandoned_at: abandoned_at} ->
            Map.merge(updates, %{abandoned_at: abandoned_at})

          _ ->
            updates
        end

      job = Job.changeset(job, updates)

      repo.update!(job)
    end)

    state
  end

  @impl true
  @doc """
  Acknowledges a failure of the job, unreserving the job and allowing it to be picked up again
  """
  def nack(%Honeydew.Job{private: id} = job, %QState{repo: repo} = state) do
    debug_log("NACK JOB")

    self_pid = self()

    repo.transaction(fn ->
      query =
        from(
          j in Job,
          where: j.id == ^id,
          where: j.queue == ^to_string(state.queue_name),
          limit: 1,
          lock: "FOR UPDATE"
        )

      repo.one!(query)
      |> Job.changeset(%{
        reserved_at: nil,
        failure_state: %{state: job.failure_private},
        nacked_until: nack_time(state)
      })
      |> repo.update!()

      Process.send_after(self_pid, :retry_available, state.retry_seconds * 1_000)
    end)

    state
  end

  defp nack_time(state) do
    now = DateTime.to_unix(DateTime.utc_now())
    now = now + state.retry_seconds
    DateTime.from_unix!(now)
  end

  #
  # Helpers
  #

  @impl true
  @doc """
  Retrieves the total number of jobs, and the in progress number of jobs
  """
  def status(%QState{repo: repo, queue_name: queue_name}) do
    query = "SELECT COUNT(*), COUNT(reserved_at) FROM jobs WHERE acked_at IS NULL AND queue = $1"

    %{rows: [[count, in_progress]]} =
      Ecto.Adapters.SQL.query!(repo, query, [to_string(queue_name)])

    %{count: count, in_progress: in_progress}
  end

  @impl true
  def filter(%QState{repo: repo, queue_name: queue_name}, function) do
    query =
      from(
        j in Job,
        where: is_nil(j.acked_at),
        where: j.queue == ^to_string(queue_name)
      )

    repo.all(query)
    |> Stream.map(&deserialize/1)
    |> Enum.filter(function)
  end

  @impl true
  def cancel(%Honeydew.Job{private: id} = job, %QState{repo: repo} = state) do
    query =
      from(
        j in Job,
        where: j.id == ^id,
        where: is_nil(j.acked_at),
        limit: 1
      )

    reply =
      case repo.one(query) do
        nil ->
          {:error, :not_found}

        %Job{reserved_at: nil} ->
          ack(job, state)
          :ok

        %Job{} ->
          {:error, :in_progress}
      end

    {reply, state}
  end

  @impl true
  def handle_info(
        {:notification, _connection_pid, _ref, @config_channel, _payload},
        %{private: private_state} = state
      ) do
    debug_log("Job config updates, reloading config")
    {:noreply, %{state | private: refresh_config(private_state)}}
  end

  def handle_info({:notification, _connection_pid, _ref, @jobs_channel, _payload}, state) do
    debug_log("Notified of new job, poking the queue")
    {:noreply, dispatch_queue(state)}
  end

  def handle_info(msg, state) when msg in [:retry_available, :run_now] do
    {:noreply, dispatch_queue(state)}
  end

  def handle_info({:ping, pid}, state) do
    send(pid, :pong)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn(fn ->
      [
        "[HoneydewEctoNotifyQueue] Queue ",
        inspect(self()),
        "received unexpected message ",
        inspect(msg)
      ]
    end)

    {:noreply, state}
  end

  defp serialize(%Honeydew.Job{} = job, %QState{queue_name: queue_name}) do
    {function, arguments} = job.task

    %{
      queue: Atom.to_string(queue_name),
      function: Atom.to_string(function),
      arguments: %{args: arguments},
      failure_state: %{state: nil}
    }
  end

  defp deserialize(%Job{} = job) do
    # nil, private, failure_private, task, from, result, by, queue, monitor, enqueued_at, started_at, completed_at
    {nil, job.id, job.failure_state["state"],
     {String.to_atom(job.function), job.arguments["args"]}, nil, nil, nil,
     String.to_atom(job.queue), nil, job.inserted_at, nil, nil}
    |> Honeydew.Job.from_record()
  end

  @spec refresh_config(%QState{}) :: :ok | {:error, any()}
  defp refresh_config(%QState{repo: repo, queue_name: queue_name, per_queue_suspension: per_queue_suspension} = state) do
    with suspended_key <- JobConfig.suspended_key(queue_name, per_queue_suspension),
      {:ok, config} <- HoneydewEctoNotifyQueue.Config.get_config(repo, suspended_key) do
      suspended = String.to_existing_atom(config.value)

      if suspended do
        debug_log("Synchronised queue status to suspended")
        Honeydew.suspend(queue_name)
      else
        debug_log("Synchronised queue status to resumed")
        Honeydew.resume(queue_name)
      end

      Map.put(state, :database_suspended, suspended)
    else
      error ->
        Logger.warn(fn ->
          [
            "[HoneydewEctoNotifyQueue] There was an error fetching the 'suspended' job configuration",
            inspect(error)
          ]
        end)

        state
    end
  end

  defp dispatch_queue(%Honeydew.Queue.State{private: %QState{queue_name: queue_name}} = state) do
    debug_log("Dispatching to queue #{queue_name}")
    Honeydew.Queue.dispatch(state)
  end

  defp debug_log(msg) do
    Logger.debug(fn -> ["[HoneydewEctoNotifyQueue] ", msg] end)
  end
end
