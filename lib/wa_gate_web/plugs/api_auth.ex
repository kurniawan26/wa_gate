defmodule WaGateWeb.Plugs.ApiAuth do
  import Plug.Conn
  alias WaGate.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Auth.get_user_by_api_key(token) do
          nil ->
            unauthorized(conn)

          user ->
            assign(conn, :current_user, user)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "Unauthorized"})
    |> halt()
  end
end
