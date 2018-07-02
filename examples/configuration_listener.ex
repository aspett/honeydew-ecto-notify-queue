defmodule ConfigurationListener do
  use GenServer

  @config_channel HoneydewEctoNotifyQueue.config_channel()

  defmodule State do
    defstruct [:notification_ref]
  end

  def init(notifier) do
    {:ok, ref} = start_config_notifier(notifier)

    {:ok, %{notification_ref: ref}}
  end

  def handle_info({:notification, _connection_pid, ref, @config_channel, _payload}, %{notification_ref: ref}) do
    {:ok, config} = HoneydewEctoNotifyQueue.Config.get_config("suspended")
    Logger.debug("Synchronised suspended configuration =" <> config.value)

    {:noreply, state}
  end

  defp start_config_notifier(notifier) do
    pid = Process.whereis(notifier)
    Postgrex.Notifications.listen(pid, @config_channel)
  end
end
