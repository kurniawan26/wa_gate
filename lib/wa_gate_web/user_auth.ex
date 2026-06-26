defmodule WaGateWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller
  use WaGateWeb, :verified_routes

  alias WaGate.Auth
  alias WaGate.Crypto

  # --- Plug callbacks ---

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Auth.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Anda harus login terlebih dahulu.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  # --- LiveView on_mount hooks ---

  def on_mount(:require_auth, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Anda harus login terlebih dahulu.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      user_id = Map.get(session, "user_id")
      user_id && Auth.get_user(user_id)
    end)
  end

  # --- Session management ---

  def log_in_user(conn, user, password) do
    enc_key = Crypto.derive_user_key(password, user.enc_salt)

    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:enc_key, Base.encode64(enc_key))
    |> put_session(:user_name, user.name)
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/login")
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
