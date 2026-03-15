defmodule WaGate.Messaging do
  import Ecto.Query, warn: false
  alias WaGate.Repo
  alias WaGate.Messaging.Message
  alias WaGate.Messaging.InboundMessage
  alias WaGate.Workers.MessageWorker

  def enqueue_message(recipient, text) do
    Repo.transaction(fn ->
      # 1. Simpan ke tabel outbound_messages dulu sebagai 'pending'
      {:ok, message} =
        %Message{}
        |> Message.changeset(%{recipient_number: recipient, payload: text, status: "pending"})
        |> Repo.insert()

      # 2. Masukkan ke antrean Oban
      %{message_id: message.id}
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

  def list_recent_messages(limit \\ 50) do
    inbound =
      Repo.all(
        from m in InboundMessage,
          order_by: [desc: m.inserted_at],
          limit: ^limit,
          preload: [:whatsapp_session]
      )
      |> Enum.map(&Map.put(&1, :kind, :inbound))

    outbound =
      Repo.all(
        from m in Message,
          where: m.status in ["sent", "failed", "pending"],
          order_by: [desc: m.inserted_at],
          limit: ^limit,
          preload: [:whatsapp_session]
      )
      |> Enum.map(&Map.put(&1, :kind, :outbound))

    (inbound ++ outbound)
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
    |> Enum.take(limit)
  end
end
