defmodule WaGate.Workers.DailyResetWorker do
  use Oban.Worker, queue: :messaging

  alias WaGate.Repo
  alias WaGate.Accounts.Session

  @impl Oban.Worker
  def perform(_job) do
    {count, _} = Repo.update_all(Session, set: [messages_sent_today: 0])
    {:ok, %{reset_count: count}}
  end
end
