defmodule WaGateWeb.Api.MessageController do
  use WaGateWeb, :controller
  alias WaGate.Messaging

  @doc """
  Endpoint untuk mengirim pesan dari sistem eksternal.
  Contoh JSON: {"to": "62812345678", "text": "Halo dari Sistem CRM!"}
  """
  def create(conn, %{"to" => to, "text" => text}) do
    user_id = conn.assigns.current_user.id

    case Messaging.enqueue_message(to, text, user_id) do
      {:ok, message} ->
        conn
        |> put_status(:accepted)
        |> json(%{
          status: "queued",
          message_id: message.id,
          info: "Pesan telah masuk antrean pengiriman"
        })

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Gagal memproses pesan"})
    end
  end
end
