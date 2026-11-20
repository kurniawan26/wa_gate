defmodule WaGateWeb.Api.MessageControllerTest do
  use WaGateWeb.ConnCase, async: true

  import WaGate.MessagingFixtures

  setup %{conn: conn} do
    user = user_fixture()
    {:ok, key, _} = WaGate.Auth.generate_api_key(user)
    %{conn: put_req_header(conn, "accept", "application/json"), key: key}
  end

  test "menerima API key yang valid", %{conn: conn, key: key} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> key)
      |> post(~p"/api/messages", %{"to" => "081234567890", "text" => "halo"})

    assert %{"status" => "queued"} = json_response(conn, 202)
  end

  test "menolak API key yang salah", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer wag_salah")
      |> post(~p"/api/messages", %{"to" => "081234567890", "text" => "halo"})

    assert json_response(conn, 401)
  end
end
