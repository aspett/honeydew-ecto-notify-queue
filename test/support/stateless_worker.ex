defmodule HoneydewEctoNotifyQueue.StatelessWorker do
  @behaviour Honeydew.Worker
  use Honeydew.Progress

  def send_msg(to, msg) do
    to = :erlang.list_to_pid(to)
    send(to, msg)
  end

  def return(term) do
    term
  end

  def sleep(time) do
    Process.sleep(time)
  end

  def sleep_send(to, msg, time) do
    Process.sleep(time)
    send_msg(to, msg)
  end

  def crash(pid) do
    pid = :erlang.list_to_pid(pid)
    send(pid, :job_ran)
    raise "ignore this crash"
  end

  def emit_progress(update) do
    progress(update)
    Process.sleep(500)
  end
end
