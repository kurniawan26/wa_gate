defmodule WaGateWeb.Plugs.VerifyWebhookSignatureTest do
  # Tidak async karena mengubah Application env.
  use WaGateWeb.ConnCase, async: false

  @secret "test-webhook-secret"
  @body ~s({"event":"message.ack","session":"x","payload":{}})

  defp sign(body, secret \\ @secret) do
    :crypto.mac(:hmac, :sha512, secret, body) |> Base.encode16(case: :lower)
  end

  defp post_webhook(conn, body, headers) do
    conn
    |> put_req_header("content-type", "application/json")
    |> then(&Enum.reduce(headers, &1, fn {k, v}, c -> put_req_header(c, k, v) end))
    |> post(~p"/api/webhooks/whatsapp", body)
  end

  describe "dengan WEBHOOK_SECRET" do
    setup do
      put_app_env(:webhook_secret, @secret)
    end

    test "menerima signature yang valid", %{conn: conn} do
      conn =
        post_webhook(conn, @body, [
          {"x-webhook-hmac", sign(@body)},
          {"x-webhook-hmac-algorithm", "sha512"}
        ])

      assert conn.status == 200
    end

    test "menolak signature dengan kunci salah", %{conn: conn} do
      conn =
        post_webhook(conn, @body, [
          {"x-webhook-hmac", sign(@body, "wrong")},
          {"x-webhook-hmac-algorithm", "sha512"}
        ])

      assert conn.status == 401
    end

    test "menolak body yang diubah", %{conn: conn} do
      tampered = String.replace(@body, "message.ack", "message")

      conn =
        post_webhook(conn, tampered, [
          {"x-webhook-hmac", sign(@body)},
          {"x-webhook-hmac-algorithm", "sha512"}
        ])

      assert conn.status == 401
    end

    test "menolak request tanpa signature", %{conn: conn} do
      assert post_webhook(conn, @body, []).status == 401
    end
  end

  test "tanpa WEBHOOK_SECRET verifikasi dilewati", %{conn: conn} do
    put_app_env(:webhook_secret, nil)
    assert post_webhook(conn, @body, []).status == 200
  end

  test "cocok dengan contoh dari dokumentasi WAHA" do
    body = ~s({"event":"message","session":"default","engine":"WEBJS"})

    assert sign(body, "my-secret-key") ==
             "208f8a55dde9e05519e898b10b89bf0d0b3b0fdf11fdbf09b6b90476301b98d8097c462b2b17a6ce93b6b47a136cf2e78a33a63f6752c2c1631777076153fa89"
  end
end
