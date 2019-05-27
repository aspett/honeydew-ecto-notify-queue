defmodule HoneydewEctoNotifyQueueIntegrationTest do
  use ExUnit.Case

  # Test the ecto queue based off the integration tests Honeydew uses for
  # it's erlang queue implementation

  alias HoneydewEctoNotifyQueue.{StatelessWorker, QueueHelper, Repo}
  alias Honeydew.Job

  import QueueHelper, only: [pid_to_list: 1]

  @receive_timeout 500

  defp self_pid do
    pid_to_list(self())
  end

  setup_all do
    children = [
      Repo,
      %{
        id: :notifier,
        start: {Postgrex.Notifications, :start_link, [Repo.config() ++ [name: Notifier]]}
      }
    ]

    {:ok, _pid} =
      Supervisor.start_link(
        children,
        strategy: :one_for_one,
        name: HoneydewEctoNotifyQueue.Supervisor
      )

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    queue = :"#{:erlang.monotonic_time()}_#{:erlang.unique_integer()}"

    spec =
      Honeydew.queue_spec(queue,
        queue:
          {HoneydewEctoNotifyQueue,
           [
             repo: HoneydewEctoNotifyQueue.Repo,
             # seconds
             max_job_time: 3_600,
             # seconds,
             retry_seconds: 15,
             notifier: Notifier
           ]},
        failure_mode: {Honeydew.FailureMode.Retry, times: 3}
      )

    {_queue, {queue_module, startfn, args}, restart, timeout, type, _module} = spec

    spec = %{
      id: queue_module,
      start: {queue_module, startfn, args},
      type: type,
      restart: restart,
      shutdown: timeout
    }

    {:ok, _pid} = start_supervised(spec)

    spec = Honeydew.worker_spec(queue, StatelessWorker, [])

    {_queue, {worker_module, startfn, args}, restart, timeout, type, _module} = spec

    spec = %{
      id: worker_module,
      start: {worker_module, startfn, args},
      type: type,
      restart: restart,
      shutdown: timeout
    }

    {:ok, _w_pid} = start_supervised(spec)

    [queue: queue]
  end

  setup %{queue: queue} do
    Honeydew.suspend(queue)

    QueueHelper.cancel_until_cleared(queue)
    QueueHelper.wait_until_ready(queue)

    Honeydew.resume(queue)

    :ok
  end

  test "async/3", %{queue: queue} do
    %Job{} = {:send_msg, [self_pid(), "hi"]} |> Honeydew.async(queue)

    assert_receive "hi", @receive_timeout
  end

  test "suspend/1", %{queue: queue} do
    Honeydew.suspend(queue)
    {:send_msg, [self_pid(), "hi"]} |> Honeydew.async(queue)
    assert Honeydew.status(queue) |> get_in([:queue, :count]) == 1
    assert Honeydew.status(queue) |> get_in([:queue, :suspended]) == true
    refute_receive "hi", @receive_timeout
  end

  test "resume/1", %{queue: queue} do
    Honeydew.suspend(queue)
    {:send_msg, [self_pid(), "hi"]} |> Honeydew.async(queue)
    refute_receive "hi", @receive_timeout
    Honeydew.resume(queue)
    assert_receive "hi", @receive_timeout
  end

  test "status/1", %{queue: queue} do
    {:sleep, [1_000]} |> Honeydew.async(queue)
    Honeydew.suspend(queue)
    Enum.each(1..3, fn _ -> {:send_msg, [self_pid(), "hi"]} |> Honeydew.async(queue) end)
    # let monitors send acks
    Process.sleep(200)
    assert %{queue: %{count: 4, in_progress: 1, suspended: true}} = Honeydew.status(queue)
  end

  test "filter/1", %{queue: queue} do
    Honeydew.suspend(queue)

    {:sleep, [1_000]} |> Honeydew.async(queue)
    {:sleep, [2_000]} |> Honeydew.async(queue)
    {:sleep, [2_000]} |> Honeydew.async(queue)
    Enum.each(1..3, fn i -> {:send_msg, [self_pid(), i]} |> Honeydew.async(queue) end)

    jobs =
      Honeydew.filter(queue, fn
        %Job{task: {:sleep, [2_000]}} -> true
        _ -> false
      end)

    assert Enum.count(jobs) == 2

    Enum.each(jobs, fn job ->
      assert Map.get(job, :task) == {:sleep, [2_000]}
    end)
  end

  test "cancel/1 when job hasn't executed", %{queue: queue} do
    Honeydew.suspend(queue)

    assert :ok =
             {:send_msg, [self_pid(), "hi"]}
             |> Honeydew.async(queue)
             |> Honeydew.cancel()

    Honeydew.resume(queue)

    refute_receive "hi", @receive_timeout
  end

  test "cancel/1 when job is in progress", %{queue: queue} do
    assert {:error, :in_progress} =
             {:sleep_send, [self_pid(), "hi", 200]}
             |> Honeydew.async(queue)
             |> Honeydew.cancel()

    assert_receive "hi", @receive_timeout
  end

  test "should not leak monitors", %{queue: queue} do
    queue_process = Honeydew.get_queue(queue)

    Enum.each(0..500, fn _ ->
      {:send_msg, [self_pid(), "hi"]} |> Honeydew.async(queue)
      assert_receive "hi", @receive_timeout
    end)

    {:monitors, monitors} = :erlang.process_info(queue_process, :monitors)
    assert Enum.count(monitors) < 20
  end
end
