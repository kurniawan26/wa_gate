defmodule WaGateWeb.Plugs.VerifyWebhookSignature do
  @moduledoc """
  Memverifikasi header `X-Webhook-Hmac` dari WAHA: HMAC-SHA512 (hex) atas
  raw body dengan kunci `WEBHOOK_SECRET`.

  Bila `:webhook_secret` tidak dikonfigurasi (hanya diizinkan di dev/test),
  verifikasi dilewati.
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case Application.get_env(:wa_gate, :webhook_secret) do
      secret when secret in [nil, ""] -> conn
      secret -> verify(conn, secret)
    end
  end

  defp verify(conn, secret) do
    raw_body = conn.assigns[:raw_body] || ""
    expected = :crypto.mac(:hmac, :sha512, secret, raw_body) |> Base.encode16(case: :lower)

    with [algorithm] <- get_req_header(conn, "x-webhook-hmac-algorithm"),
         "sha512" <- String.downcase(algorithm),
         [given] <- get_req_header(conn, "x-webhook-hmac"),
         true <- Plug.Crypto.secure_compare(expected, String.downcase(given)) do
      conn
    else
      _ ->
        Logger.warning("Webhook ditolak: signature HMAC tidak valid atau tidak ada")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, ~s({"error":"invalid signature"}))
        |> halt()
    end
  end
end
