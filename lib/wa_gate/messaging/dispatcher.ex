defmodule WaGate.Messaging.Dispatcher do
  @moduledoc """
  Pemilihan sesi pengirim dan pencatatan kuota harian.

  Kuota direservasi secara atomik (`UPDATE ... WHERE messages_sent_today <
  max_daily_messages`) sebelum pesan dikirim, sehingga worker yang berjalan
  paralel tidak bisa melampaui limit atau saling menimpa counter.
  """
  import Ecto.Query
  alias WaGate.Repo
  alias WaGate.Accounts.Session

  @max_reserve_attempts 5

  @doc """
  Mereservasi satu slot kuota pada sesi `connected` milik user yang paling
  jarang dipakai (sesi yang belum pernah dipakai didahulukan).
  """
  def reserve_available_session(user_id),
    do: reserve_available_session(user_id, @max_reserve_attempts)

  defp reserve_available_session(_user_id, 0), do: {:error, :no_available_session}

  defp reserve_available_session(user_id, attempts_left) do
    case get_available_session(user_id) do
      nil ->
        {:error, :no_available_session}

      session ->
        case reserve_session(session.id) do
          {:ok, session} -> {:ok, session}
          # Diambil worker lain di sela query; coba kandidat berikutnya.
          {:error, _} -> reserve_available_session(user_id, attempts_left - 1)
        end
    end
  end

  def get_available_session(user_id) do
    from(s in Session,
      where: s.user_id == ^user_id,
      where: s.status == "connected",
      where: s.messages_sent_today < s.max_daily_messages,
      order_by: [asc_nulls_first: s.last_used_at, asc: s.messages_sent_today],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Mereservasi satu slot kuota pada sesi tertentu. Mengembalikan
  `{:error, :not_found | :not_connected | :daily_limit_reached}` bila gagal.
  """
  def reserve_session(session_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    query =
      from s in Session,
        where: s.id == ^session_id,
        where: s.status == "connected",
        where: s.messages_sent_today < s.max_daily_messages,
        select: s

    case Repo.update_all(query, inc: [messages_sent_today: 1], set: [last_used_at: now]) do
      {1, [session]} -> {:ok, session}
      {0, _} -> {:error, reservation_failure(session_id)}
    end
  end

  defp reservation_failure(session_id) do
    case Repo.get(Session, session_id) do
      nil -> :not_found
      %Session{status: "connected"} -> :daily_limit_reached
      _ -> :not_connected
    end
  end

  @doc "Mengembalikan slot kuota yang direservasi bila pesan tidak jadi terkirim."
  def release_session(session_id) do
    from(s in Session, where: s.id == ^session_id and s.messages_sent_today > 0)
    |> Repo.update_all(inc: [messages_sent_today: -1])

    :ok
  end
end
