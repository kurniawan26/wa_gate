defmodule WaGate.Messaging do
  import Ecto.Query, warn: false
  alias WaGate.Repo
  alias WaGate.Messaging.Message
  alias WaGate.Messaging.InboundMessage
  alias WaGate.Accounts.Session
  alias WaGate.Workers.MessageWorker
  alias WaGate.Crypto

  @feed_topic "messages:feed"

  @doc """
  Menyimpan pesan keluar (terenkripsi) dan menjadwalkan job pengiriman.

  Teks asli **tidak** disimpan di argumen job; worker akan mendekripsi
  `payload` dari database.

  Opsi:
    * `:session_id` — paksa pengiriman lewat sesi tertentu (milik user).
  """
  def enqueue_message(recipient, text, user_id, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    text = if is_binary(text), do: String.trim(text), else: ""
    recipient = if is_integer(recipient), do: Integer.to_string(recipient), else: recipient

    changeset =
      %Message{user_id: user_id, whatsapp_session_id: session_id}
      |> Message.changeset(%{
        recipient_number: recipient,
        payload: if(text == "", do: nil, else: Crypto.encrypt(text, Crypto.app_key())),
        status: "pending"
      })
      |> then(fn cs ->
        if text == "",
          do: %{
            cs
            | errors: [
                {:payload, {"teks pesan wajib diisi", []}} | Keyword.delete(cs.errors, :payload)
              ]
          },
          else: cs
      end)

    Repo.transaction(fn ->
      with {:ok, message} <- Repo.insert(changeset),
           {:ok, _job} <-
             %{message_id: message.id, user_id: user_id, session_id: session_id}
             |> MessageWorker.new()
             |> Oban.insert() do
        message
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, message} ->
        broadcast_outbound(message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc "Merangkum error changeset menjadi satu kalimat untuk flash / respons API."
  def error_summary(%Ecto.Changeset{} = cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
    |> Enum.flat_map(fn {_field, msgs} -> msgs end)
    |> Enum.join(", ")
  end

  def error_summary(reason), do: format_reason(reason)

  @doc "Mengembalikan teks asli pesan keluar."
  def decrypt_payload(%Message{payload: payload}), do: Crypto.decrypt(payload, Crypto.app_key())

  def mark_sent(%Message{} = message, session_id) do
    message
    |> Message.changeset(%{status: "sent", whatsapp_session_id: session_id, error_reason: nil})
    |> Repo.update()
    |> tap_broadcast()
  end

  def mark_failed(%Message{} = message, reason, attrs \\ %{}) do
    message
    |> Message.changeset(
      Map.merge(%{status: "failed", error_reason: format_reason(reason)}, attrs)
    )
    |> Repo.update()
    |> tap_broadcast()
  end

  def record_attempt_error(%Message{} = message, reason, attempt) do
    message
    |> Message.changeset(%{error_reason: format_reason(reason), retry_count: attempt})
    |> Repo.update()
  end

  def format_reason({:http_status, code}), do: "WhatsApp engine membalas status #{code}"

  def format_reason({:not_delivered, reason}),
    do: "tidak dapat terhubung ke WhatsApp engine (#{inspect(reason)})"

  def format_reason(reason) when is_binary(reason), do: String.slice(reason, 0, 255)
  def format_reason(%{__exception__: true} = e), do: format_reason(Exception.message(e))
  def format_reason(reason), do: format_reason(inspect(reason))

  defp tap_broadcast({:ok, message} = result) do
    broadcast_outbound(message)
    result
  end

  defp tap_broadcast(error), do: error

  # Payload broadcast hanya berisi metadata, tanpa isi pesan.
  defp broadcast_outbound(%Message{} = message) do
    Phoenix.PubSub.broadcast(
      WaGate.PubSub,
      @feed_topic,
      {:outbound_updated, Map.take(message, [:id, :user_id, :status, :recipient_number])}
    )
  end

  def save_inbound_message(attrs) do
    result =
      %InboundMessage{}
      |> InboundMessage.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing, conflict_target: :external_id)

    case result do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(WaGate.PubSub, @feed_topic, {:new_inbound, message})
        {:ok, message}

      error ->
        error
    end
  end

  def list_recent_messages(user_id, limit \\ 50, session_id \\ nil) do
    key = Crypto.app_key()
    session_ids = resolve_session_ids(user_id, session_id)

    inbound =
      Repo.all(
        from m in InboundMessage,
          where: m.whatsapp_session_id in ^session_ids,
          order_by: [desc: m.inserted_at],
          limit: ^limit,
          preload: [:whatsapp_session]
      )
      |> Enum.map(&(&1 |> Map.put(:kind, :inbound) |> decrypt_inbound(key)))

    outbound =
      Repo.all(
        from m in outbound_scope(user_id, session_id, session_ids),
          order_by: [desc: m.inserted_at],
          limit: ^limit,
          preload: [:whatsapp_session]
      )
      |> Enum.map(&(&1 |> Map.put(:kind, :outbound) |> decrypt_outbound(key)))

    (inbound ++ outbound)
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
    |> Enum.take(limit)
  end

  def list_contacts(user_id, session_id \\ nil) do
    key = Crypto.app_key()
    session_ids = resolve_session_ids(user_id, session_id)

    inbound =
      Repo.all(
        from m in InboundMessage,
          where: m.whatsapp_session_id in ^session_ids,
          order_by: [desc: m.inserted_at]
      )
      |> Enum.map(fn m ->
        %{
          number: m.sender_number,
          name: m.sender_name,
          preview: safe_decrypt(m.body, key) || "(non-text)",
          last_at: m.inserted_at,
          kind: :inbound
        }
      end)

    outbound =
      Repo.all(
        from m in outbound_scope(user_id, session_id, session_ids),
          order_by: [desc: m.inserted_at]
      )
      |> Enum.map(fn m ->
        %{
          number: m.recipient_number,
          name: nil,
          preview: safe_decrypt(m.payload, key) || "",
          last_at: m.inserted_at,
          kind: :outbound
        }
      end)

    (inbound ++ outbound)
    |> Enum.sort_by(& &1.last_at, {:desc, NaiveDateTime})
    |> Enum.uniq_by(& &1.number)
  end

  def list_thread(number, user_id) do
    key = Crypto.app_key()
    session_ids = user_session_ids(user_id)

    inbound =
      Repo.all(
        from m in InboundMessage,
          where: m.sender_number == ^number and m.whatsapp_session_id in ^session_ids,
          order_by: [asc: m.inserted_at],
          preload: [:whatsapp_session]
      )
      |> Enum.map(&(&1 |> Map.put(:kind, :inbound) |> decrypt_inbound(key)))

    outbound =
      Repo.all(
        from m in outbound_scope(user_id, nil, session_ids),
          where: m.recipient_number == ^number,
          order_by: [asc: m.inserted_at],
          preload: [:whatsapp_session]
      )
      |> Enum.map(&(&1 |> Map.put(:kind, :outbound) |> decrypt_outbound(key)))

    (inbound ++ outbound)
    |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})
  end

  # --- helpers ---

  defp user_session_ids(user_id) do
    Repo.all(from s in Session, where: s.user_id == ^user_id, select: s.id)
  end

  # Pesan keluar milik user: dikenali dari user_id (termasuk yang masih
  # pending / gagal dan belum punya sesi), atau dari sesi milik user untuk
  # data lama sebelum kolom user_id ada.
  defp outbound_scope(user_id, nil, session_ids) do
    from m in Message, where: m.user_id == ^user_id or m.whatsapp_session_id in ^session_ids
  end

  defp outbound_scope(user_id, session_id, _session_ids) do
    from m in Message,
      where: m.whatsapp_session_id == ^session_id,
      where: m.user_id == ^user_id or is_nil(m.user_id)
  end

  defp resolve_session_ids(_user_id, session_id) when is_binary(session_id), do: [session_id]
  defp resolve_session_ids(user_id, _), do: user_session_ids(user_id)

  defp decrypt_inbound(%{body: body} = msg, key) do
    %{msg | body: safe_decrypt(body, key)}
  end

  defp decrypt_outbound(%{payload: payload} = msg, key) do
    %{msg | payload: safe_decrypt(payload, key)}
  end

  defp safe_decrypt(nil, _key), do: nil
  defp safe_decrypt(value, key), do: Crypto.decrypt(value, key) || value
end
