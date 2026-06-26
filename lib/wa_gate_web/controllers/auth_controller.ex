defmodule WaGateWeb.AuthController do
  use WaGateWeb, :controller

  alias WaGate.Auth
  alias WaGateWeb.UserAuth

  def login(conn, _params) do
    render(conn, :login, error_message: nil)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Auth.authenticate(email, password) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user, password)
        |> redirect(to: ~p"/sessions")

      {:error, _} ->
        render(conn, :login, error_message: "Email atau password salah.")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Berhasil logout.")
    |> UserAuth.log_out_user()
  end

  def register(conn, _params) do
    changeset = Auth.change_user_registration()
    render(conn, :register, changeset: changeset)
  end

  def create_user(conn, %{"user" => params}) do
    case Auth.register(params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Akun berhasil dibuat, silakan login.")
        |> redirect(to: ~p"/login")

      {:error, changeset} ->
        render(conn, :register, changeset: changeset)
    end
  end
end
