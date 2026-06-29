defmodule WaGateWeb.Api.MessageController do
  use WaGateWeb, :controller
  alias WaGate.Messaging
  alias WaGate.Accounts

  @doc """
  Endpoint untuk mengirim pesan dari sistem eksternal.
  Contoh JSON: {"to": "62812345678", "text": "Halo dari Sistem CRM!"}
  Opsional: {"session_id": "<uuid>"} atau {"from_number": "628xx"} untuk memilih sesi pengirim.
  """
  def create(conn, %{"to" => to, "text" => text} = params) do
    user = conn.assigns.current_user

    with {:ok, session_id} <- resolve_session_param(params, user) do
      case Messaging.enqueue_message(to, text, user.id, session_id: session_id) do
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
    else
      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session tidak ditemukan"})

      {:error, :phone_not_found} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Nomor pengirim tidak ditemukan di sesi Anda"})
    end
  end

  defp resolve_session_param(%{"session_id" => sid}, user) when is_binary(sid) and sid != "" do
    case Accounts.get_user_session(sid, user.id) do
      nil -> {:error, :session_not_found}
      session -> {:ok, session.id}
    end
  end

  defp resolve_session_param(%{"from_number" => phone}, user) when is_binary(phone) and phone != "" do
    case Accounts.get_user_session_by_phone(phone, user.id) do
      nil -> {:error, :phone_not_found}
      session -> {:ok, session.id}
    end
  end

  defp resolve_session_param(_params, _user), do: {:ok, nil}
end
