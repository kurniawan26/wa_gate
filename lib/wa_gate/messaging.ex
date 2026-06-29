defmodule WaGate.Messaging do
  import Ecto.Query, warn: false
  alias WaGate.Repo
  alias WaGate.Messaging.Message
  alias WaGate.Messaging.InboundMessage
  alias WaGate.Accounts.Session
  alias WaGate.Workers.MessageWorker
  alias WaGate.Crypto

  def enqueue_message(recipient, text, user_id, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)

    Repo.transaction(fn ->
      encrypted_payload = Crypto.encrypt(text, Crypto.app_key())

      {:ok, message} =
        %Message{}
        |> Message.changeset(%{
          recipient_number: recipient,
          payload: encrypted_payload,
          status: "pending",
          user_id: user_id
        })
        |> Repo.insert()

      %{message_id: message.id, plaintext: text, user_id: user_id, session_id: session_id}
      |> MessageWorker.new()
      |> Oban.insert!()

      message
    end)
  end

  def save_inbound_message(attrs) do
    result =
      %InboundMessage{}
      |> InboundMessage.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing, conflict_target: :external_id)

    case result do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(WaGate.PubSub, "messages:feed", {:new_inbound, message})
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
        from m in Message,
          where: m.whatsapp_session_id in ^session_ids and m.status in ["sent", "failed", "pending"],
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
      Repo.all(from m in InboundMessage,
        where: m.whatsapp_session_id in ^session_ids,
        order_by: [desc: m.inserted_at])
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
      Repo.all(from m in Message,
        where: m.whatsapp_session_id in ^session_ids,
        order_by: [desc: m.inserted_at])
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
        from m in Message,
          where: m.recipient_number == ^number and m.whatsapp_session_id in ^session_ids,
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
