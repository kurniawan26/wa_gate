defmodule WaGateWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Body reader untuk `Plug.Parsers` yang menyimpan raw body request webhook
  di `conn.assigns.raw_body`, karena signature HMAC dihitung atas byte asli,
  bukan atas JSON hasil parsing. Hanya aktif untuk path webhook supaya
  request lain tidak menyimpan salinan body.
  """

  @webhook_paths [["api", "webhooks", "whatsapp"]]

  def read_body(%Plug.Conn{path_info: path} = conn, opts) when path in @webhook_paths do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} -> {:ok, body, append(conn, body)}
      {:more, body, conn} -> {:more, body, append(conn, body)}
      other -> other
    end
  end

  def read_body(conn, opts), do: Plug.Conn.read_body(conn, opts)

  defp append(conn, chunk) do
    Plug.Conn.assign(conn, :raw_body, (conn.assigns[:raw_body] || "") <> chunk)
  end
end
