defmodule WaGateWeb.WebhookController do
  use WaGateWeb, :controller
  alias WaGate.Accounts
  alias WaGate.Messaging
  alias WaGate.Crypto

  def receive(conn, params) do
    case params do
      %{"event" => "connection.update", "instance" => phone, "data" => %{"state" => "open"}} ->
        case Accounts.get_session_by_phone(phone) do
          nil ->
            :ok

          session ->
            {:ok, updated} = Accounts.update_session(session, %{status: "connected"})
            Phoenix.PubSub.broadcast(WaGate.PubSub, "session:#{updated.id}", :connected)
        end

      %{"event" => "connection.update", "instance" => phone, "data" => %{"state" => state}}
      when state in ["close", "connecting"] ->
        case Accounts.get_session_by_phone(phone) do
          nil -> :ok
          session -> Accounts.update_session(session, %{status: "disconnected"})
        end

      %{"event" => "messages.upsert", "instance" => phone, "data" => data}
      when not is_nil(data) ->
        handle_inbound_message(phone, data)

      _ ->
        :ok
    end

    send_resp(conn, 200, "")
  end

  defp handle_inbound_message(phone, data) do
    with %{"key" => %{"remoteJid" => jid, "fromMe" => false, "id" => ext_id}} <- data,
         session when not is_nil(session) <- Accounts.get_session_by_phone(phone) do
      sender_number = extract_sender_number(jid)
      body = get_in(data, ["message", "conversation"]) ||
             get_in(data, ["message", "extendedTextMessage", "text"])

      encrypted_body = if body, do: Crypto.encrypt(body, Crypto.app_key()), else: nil

      Messaging.save_inbound_message(%{
        external_id: ext_id,
        sender_number: sender_number,
        sender_name: data["pushName"],
        body: encrypted_body,
        message_type: data["messageType"] || "unknown",
        raw_payload: data,
        whatsapp_session_id: session.id
      })
    else
      _ -> :ok
    end
  end

  # Nomor biasa: "6285887453948@s.whatsapp.net" → "6285887453948"
  # LID format:  "207653246636271@lid"          → "207653246636271@lid" (simpan utuh)
  defp extract_sender_number(jid) do
    case String.split(jid, "@") do
      [number, "s.whatsapp.net"] -> number
      _ -> jid
    end
  end
end
