defmodule WaGateWeb.AuthController do
  use WaGateWeb, :controller

  alias WaGate.Auth
  alias WaGate.RateLimiter
  alias WaGateWeb.UserAuth

  # Batas percobaan login gagal per window.
  @login_window :timer.minutes(15)
  @login_limit_per_email 5
  @login_limit_per_ip 20

  # Batas registrasi per IP.
  @register_window :timer.hours(1)
  @register_limit_per_ip 10

  plug :require_registration_enabled when action in [:register, :create_user]

  def login(conn, _params) do
    render_login(conn, nil)
  end

  def create(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    ip_key = {:login_ip, client_ip(conn)}
    email_key = {:login_email, email |> String.trim() |> String.downcase()}

    with :ok <- RateLimiter.check(ip_key, @login_limit_per_ip, @login_window),
         :ok <- RateLimiter.check(email_key, @login_limit_per_email, @login_window) do
      case Auth.authenticate(email, password) do
        {:ok, user} ->
          RateLimiter.reset(email_key)

          conn
          |> UserAuth.log_in_user(user)
          |> redirect(to: ~p"/sessions")

        {:error, _} ->
          RateLimiter.record(ip_key, @login_window)
          RateLimiter.record(email_key, @login_window)
          render_login(conn, "Email atau password salah.")
      end
    else
      {:error, retry_after} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> render_login(
          "Terlalu banyak percobaan login. Coba lagi dalam #{div(retry_after + 59, 60)} menit."
        )
    end
  end

  def create(conn, _params), do: render_login(conn, "Email dan password wajib diisi.")

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
    ip_key = {:register_ip, client_ip(conn)}

    case RateLimiter.check(ip_key, @register_limit_per_ip, @register_window) do
      :ok ->
        RateLimiter.record(ip_key, @register_window)

        case Auth.register(params) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Akun berhasil dibuat, silakan login.")
            |> redirect(to: ~p"/login")

          {:error, changeset} ->
            render(conn, :register, changeset: changeset)
        end

      {:error, _retry_after} ->
        conn
        |> put_flash(:error, "Terlalu banyak pendaftaran dari alamat ini. Coba lagi nanti.")
        |> redirect(to: ~p"/login")
    end
  end

  defp render_login(conn, error_message) do
    render(conn, :login,
      error_message: error_message,
      registration_enabled: registration_enabled?()
    )
  end

  defp require_registration_enabled(conn, _opts) do
    if registration_enabled?() do
      conn
    else
      conn
      |> put_flash(:error, "Pendaftaran akun baru sedang ditutup.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp registration_enabled?, do: Application.get_env(:wa_gate, :registration_enabled, true)

  defp client_ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end
