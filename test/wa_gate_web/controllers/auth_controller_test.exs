defmodule WaGateWeb.AuthControllerTest do
  # Tidak async karena memakai Application env dan rate limiter global.
  use WaGateWeb.ConnCase, async: false

  import WaGate.MessagingFixtures

  test "login berhasil tidak menyimpan kunci turunan password di session", %{conn: conn} do
    user = user_fixture(%{"password" => "password123"})
    conn = post(conn, ~p"/login", %{"email" => user.email, "password" => "password123"})

    assert redirected_to(conn) == ~p"/sessions"
    assert get_session(conn, :user_id) == user.id
    refute get_session(conn, :enc_key)
  end

  test "login diblokir setelah terlalu banyak percobaan gagal", %{conn: conn} do
    user = user_fixture()

    for _ <- 1..5 do
      conn = post(build_conn(), ~p"/login", %{"email" => user.email, "password" => "salah123"})
      assert html_response(conn, 200)
    end

    conn = post(conn, ~p"/login", %{"email" => user.email, "password" => "password123"})
    assert conn.status == 429
    assert get_resp_header(conn, "retry-after") != []
    refute get_session(conn, :user_id)
  end

  test "pendaftaran bisa ditutup lewat config", %{conn: conn} do
    put_app_env(:registration_enabled, false)

    assert redirected_to(get(conn, ~p"/register")) == ~p"/login"

    conn =
      post(build_conn(), ~p"/register", %{
        "user" => %{"email" => "x@example.com", "name" => "X", "password" => "password123"}
      })

    assert redirected_to(conn) == ~p"/login"
    assert WaGate.Auth.get_user_by_email("x@example.com") == nil
  end
end
