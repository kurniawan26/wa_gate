defmodule WaGate.WhatsApp.Adapters.Evolution do
  @behaviour WaGate.WhatsApp.EngineBehaviour
  alias HTTPoison

  @base_url "http://localhost:8080"

  @impl true
  def send_message(session, to, text) do
    api_key = session.auth_data["api_key"]
    instance = session.phone_number

    url = "#{@base_url}/message/sendText/#{instance}"

    body =
      Jason.encode!(%{
        "number" => to,
        "text" => text,
        # Jeda default 1.2 detik
        "delay" => 1200
      })

    headers = [{"apikey", api_key}, {"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 201, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: 401}} -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def update_presence(session, to, presence) do
    # Logika untuk mengirim status "composing" (typing...) ke API
    # presence bisa berupa :composing atau :available
    :ok
  end

  @impl true
  def get_status(_session), do: {:ok, "connected"}
end
