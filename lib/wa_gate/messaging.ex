defmodule WaGate.Messaging do
  alias WaGate.Repo
  alias WaGate.Messaging.Message
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
end
