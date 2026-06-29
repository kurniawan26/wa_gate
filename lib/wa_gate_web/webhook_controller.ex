defmodule WaGateWeb.WebhookController do
  use WaGateWeb, :controller
  alias WaGate.Accounts
  alias WaGate.Messaging
  alias WaGate.Crypto

  def receive(conn, params) do
    case params do
      %{"event" => "session.status", "session" => phone, "payload" => %{"status" => "WORKING"}} ->
        case Accounts.get_session_by_phone(phone) do
          nil -> :ok
          session ->
            {:ok, updated} = Accounts.update_session(session, %{status: "connected"})
            Phoenix.PubSub.broadcast(WaGate.PubSub, "session:#{updated.id}", :connected)
        end

      %{"event" => "session.status", "session" => phone, "payload" => %{"status" => status}}
      when status in ["STOPPED", "FAILED"] ->
        case Accounts.get_session_by_phone(phone) do
          nil -> :ok
          session -> Accounts.update_session(session, %{status: "disconnected"})
        end

      %{"event" => "message", "session" => phone, "payload" => payload}
      when not is_nil(payload) ->
        handle_inbound_message(phone, payload)

      _ ->
        :ok
    end

    send_resp(conn, 200, "")
  end

  defp handle_inbound_message(phone, payload) do
    with %{"id" => ext_id, "from" => from, "fromMe" => false} <- payload,
         session when not is_nil(session) <- Accounts.get_session_by_phone(phone) do
      sender_number = extract_sender_number(from)
      body = payload["body"]
      encrypted_body = if body, do: Crypto.encrypt(body, Crypto.app_key()), else: nil

      Messaging.save_inbound_message(%{
        external_id: ext_id,
        sender_number: sender_number,
        sender_name: get_in(payload, ["_data", "notifyName"]),
        body: encrypted_body,
        message_type: if(body, do: "text", else: "unknown"),
        raw_payload: payload,
        whatsapp_session_id: session.id
      })
    else
      _ -> :ok
    end
  end

  # "6285887453948@c.us" → "6285887453948"
  defp extract_sender_number(from) do
    case String.split(from, "@") do
      [number, _] -> number
      _ -> from
    end
  end
end
