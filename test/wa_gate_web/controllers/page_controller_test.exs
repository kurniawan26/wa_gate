defmodule WaGateWeb.PageControllerTest do
  use WaGateWeb.ConnCase

  test "GET / tanpa login diarahkan ke halaman login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end
end
