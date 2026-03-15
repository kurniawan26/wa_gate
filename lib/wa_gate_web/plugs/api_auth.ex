defmodule WaGateWeb.Plugs.ApiAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    api_key = Application.get_env(:wa_gate, :api_key)

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when token == api_key ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Unauthorized"})
        |> halt()
    end
  end
end
