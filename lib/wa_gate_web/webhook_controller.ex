defmodule WaGateWeb.WebhookController do
  use WaGateWeb, :controller
  alias WaGate.Accounts

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

      _ ->
        :ok
    end

    send_resp(conn, 200, "")
  end
end
