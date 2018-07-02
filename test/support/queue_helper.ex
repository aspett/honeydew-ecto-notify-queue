defmodule HoneydewEctoNotifyQueue.QueueHelper do
  def wait_until_ready(queue) do
    pid = Honeydew.get_queue(queue)
    send(pid, {:ping, self()})

    receive do
      :pong ->
        :ok
    after
      10000 ->
        :ok
    end
  end

  def cancel_until_cleared(queue) do
    %{queue: %{count: count, in_progress: progress}} = Honeydew.status(queue)

    unless count == 0 && progress == 0 do
      queue
      |> Honeydew.filter(fn _ -> true end)
      |> Enum.each(&Honeydew.cancel(&1))

      Process.sleep(50)

      cancel_until_cleared(queue)
    end
  end

  def pid_to_list(pid) when is_pid(pid) do
    :erlang.pid_to_list(pid)
  end
end
