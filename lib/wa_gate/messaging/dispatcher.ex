defmodule WaGate.Messaging.Dispatcher do
  import Ecto.Query
  alias WaGate.Repo
  alias WaGate.Accounts.Session

  @doc """
  Mencari satu sesi milik user tertentu yang:
  1. Statusnya 'connected'
  2. Belum mencapai limit harian
  3. Paling jarang dipakai hari ini (Least Used)
  """
  def get_available_session(user_id) do
    query =
      from s in Session,
        where: s.user_id == ^user_id,
        where: s.status == "connected",
        where: s.messages_sent_today < s.max_daily_messages,
        order_by: [asc: s.last_used_at, asc: s.messages_sent_today],
        limit: 1

    Repo.one(query)
  end
end
