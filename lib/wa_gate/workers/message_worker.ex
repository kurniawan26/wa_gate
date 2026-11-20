defmodule WaGate.Workers.MessageWorker do
  @moduledoc """
  Mengirim satu pesan keluar lewat WhatsApp engine.

  Alur:
    1. Muat pesan; lewati bila sudah `sent`/`failed` (job duplikat).
    2. Dekripsi payload dari database (teks asli tidak disimpan di job args).
    3. Reservasi kuota sesi secara atomik (lihat `Dispatcher`).
    4. Kirim. Bila gagal sebelum terkirim, kuota dikembalikan.

  Pesan ditandai `failed` ketika error bersifat permanen, status pengiriman
  tidak pasti (untuk menghindari kirim dobel), atau attempt terakhir habis.
  """
  use Oban.Worker, queue: :messaging, max_attempts: 3

  require Logger

  alias WaGate.Repo
  alias WaGate.Accounts
  alias WaGate.Messaging
  alias WaGate.Messaging.{Message, Dispatcher}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => message_id} = args} = job) do
    case Repo.get(Message, message_id) do
      nil ->
        {:cancel, "message #{message_id} not found"}

      %Message{status: "pending"} = message ->
        deliver(message, args, job)

      %Message{status: status} ->
        # Sudah diproses oleh job lain; jangan kirim ulang.
        Logger.info("MessageWorker: skip message #{message_id} with status #{status}")
        :ok
    end
  end

  defp deliver(message, args, job) do
    case Messaging.decrypt_payload(message) do
      nil ->
        fail_permanently(message, "payload tidak dapat didekripsi")

      text ->
        session_id = Map.get(args, "session_id") || message.whatsapp_session_id

        case reserve(session_id, message.user_id || Map.get(args, "user_id")) do
          {:ok, session} -> send_via_adapter(session, message, text, job)
          {:error, :not_found} -> fail_permanently(message, "sesi pengirim tidak ditemukan")
          {:error, reason} -> retry_or_fail(message, reservation_reason(reason, session_id), job)
        end
    end
  end

  defp reserve(nil, user_id), do: Dispatcher.reserve_available_session(user_id)
  defp reserve(session_id, _user_id), do: Dispatcher.reserve_session(session_id)

  defp reservation_reason(:no_available_session, _),
    do: "tidak ada sesi WhatsApp aktif yang tersedia"

  defp reservation_reason(:not_connected, sid), do: "sesi #{sid} tidak terhubung"

  defp reservation_reason(:daily_limit_reached, sid),
    do: "sesi #{sid} sudah mencapai limit harian"

  defp send_via_adapter(session, message, text, job) do
    adapter = Application.get_env(:wa_gate, :whatsapp_engine)

    adapter.update_presence(session, message.recipient_number, :composing)
    simulate_typing(text)

    case adapter.send_message(session, message.recipient_number, text) do
      {:ok, _res} ->
        {:ok, _} = Messaging.mark_sent(message, session.id)
        :ok

      {:error, {:delivery_unknown, reason}} ->
        # Request mungkin sudah diproses WAHA. Kuota tidak dikembalikan dan
        # tidak di-retry supaya penerima tidak menerima pesan dobel.
        fail_permanently(
          message,
          "status pengiriman tidak pasti (#{inspect(reason)}), tidak dikirim ulang",
          %{whatsapp_session_id: session.id}
        )

      {:error, :engine_unauthorized} ->
        Dispatcher.release_session(session.id)
        Logger.error("MessageWorker: WAHA menolak API key (cek WAHA_API_KEY)")
        retry_or_fail(message, "WhatsApp engine menolak API key gateway", job)

      {:error, :session_not_found} ->
        Dispatcher.release_session(session.id)
        mark_session_disconnected(session)

        retry_or_fail(
          message,
          "sesi #{session.phone_number} tidak ditemukan di WhatsApp engine",
          job
        )

      {:error, :session_not_ready} ->
        Dispatcher.release_session(session.id)
        verify_session_status(adapter, session)
        retry_or_fail(message, "sesi #{session.phone_number} belum siap mengirim", job)

      {:error, reason} ->
        Dispatcher.release_session(session.id)
        retry_or_fail(message, reason, job)
    end
  end

  defp simulate_typing(text) do
    if Application.get_env(:wa_gate, :simulate_typing, true) do
      base_delay = text |> String.length() |> Kernel.*(50) |> max(1000) |> min(5000)
      jitter = :rand.uniform(1000) - 500
      Process.sleep(base_delay + jitter)
    end
  end

  defp retry_or_fail(message, reason, %Oban.Job{attempt: attempt, max_attempts: max}) do
    if attempt >= max do
      fail_permanently(message, reason, %{retry_count: attempt})
    else
      Messaging.record_attempt_error(message, reason, attempt)
      {:error, reason}
    end
  end

  defp fail_permanently(message, reason, attrs \\ %{}) do
    {:ok, _} = Messaging.mark_failed(message, reason, attrs)
    {:cancel, Messaging.format_reason(reason)}
  end

  # 422 dari WAHA juga bisa muncul untuk sebab lain; pastikan statusnya dulu
  # sebelum menandai sesi terputus.
  defp verify_session_status(adapter, session) do
    case adapter.get_status(session) do
      {:ok, "open"} -> :ok
      {:ok, _other} -> mark_session_disconnected(session)
      {:error, _} -> :ok
    end
  end

  defp mark_session_disconnected(session) do
    case Accounts.update_session(session, %{status: "disconnected"}) do
      {:ok, updated} ->
        Phoenix.PubSub.broadcast(WaGate.PubSub, "session:#{updated.id}", :disconnected)

      _ ->
        :ok
    end
  end
end
