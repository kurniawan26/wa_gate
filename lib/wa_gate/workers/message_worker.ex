defmodule WaGate.Workers.MessageWorker do
  use Oban.Worker, queue: :messaging, max_attempts: 3

  alias WaGate.Repo
  alias WaGate.Messaging.{Message, Dispatcher}
  alias WaGate.Accounts

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => message_id}}) do
    # 1. Ambil data pesan dari DB
    message = Repo.get!(Message, message_id)

    # 2. Cari nomor WA yang tersedia melalui Dispatcher
    case Dispatcher.get_available_session() do
      nil ->
        # Jika tidak ada nomor siap, kita "fail" agar Oban coba lagi nanti
        {:error, "No active WhatsApp sessions available"}

      session ->
        send_via_adapter(session, message)
    end
  end

  defp send_via_adapter(session, message) do
    # Ambil adapter dari config (Evolution API)
    adapter = Application.get_env(:wa_gate, :whatsapp_engine)

    # 3. Simulasi Mengetik (Typing...) untuk keamanan
    adapter.update_presence(session, message.recipient_number, :composing)
    # Jeda 2 detik seolah sedang mengetik
    Process.sleep(2000)

    # 4. Eksekusi Kirim Pesan
    case adapter.send_message(session, message.recipient_number, message.payload) do
      {:ok, _res} ->
        # Berhasil! Update status pesan dan pemakaian nomor
        update_message_status(message, "sent", session.id)
        update_session_usage(session)
        :ok

      {:error, :unauthorized} ->
        # Nomor logout/banned saat pengiriman
        mark_session_disconnected(session)
        {:error, "Session disconnected during sending"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper functions untuk update database
  defp update_message_status(msg, status, session_id) do
    msg |> Message.changeset(%{status: status, whatsapp_session_id: session_id}) |> Repo.update()
  end

  defp update_session_usage(session) do
    new_usage = session.messages_sent_today + 1

    session
    |> Accounts.Session.changeset(%{
      messages_sent_today: new_usage,
      last_used_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  defp mark_session_disconnected(session) do
    session |> Accounts.Session.changeset(%{status: "disconnected"}) |> Repo.update()
  end
end
