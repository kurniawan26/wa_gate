defmodule WaGate.WhatsApp.Adapters.Evolution do
  @behaviour WaGate.WhatsApp.EngineBehaviour

  @impl true
  def send_message(session, to, text) do
    instance = session.phone_number
    url = "#{get_base_url()}/message/sendText/#{instance}"

    case Req.post(url,
           json: %{"number" => to, "text" => text, "delay" => 1200},
           headers: headers()
         ) do
      {:ok, %{status: 201, body: body}} -> {:ok, body}
      {:ok, %{status: 401}} -> {:error, :unauthorized}
      {:ok, %{status: code}} -> {:error, "Evolution API returned status #{code}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def update_presence(session, to, presence) do
    instance = session.phone_number
    url = "#{get_base_url()}/chat/whatsappPresence/#{instance}"
    value = if presence == :composing, do: "composing", else: "paused"

    Req.post(url,
      json: %{"number" => to, "delay" => 1200, "presence" => value},
      headers: headers()
    )

    :ok
  end

  def create_instance(phone_number) do
    url = "#{get_base_url()}/instance/create"

    case Req.post(url, json: %{instanceName: phone_number, qrcode: true, integration: "WHATSAPP-BAILEYS"}, headers: headers()) do
      {:ok, %{status: status}} when status in [200, 201] -> {:ok, :created}
      {:ok, %{status: 403}} -> {:ok, :already_exists}
      {:ok, %{status: code}} -> {:error, "Evolution returned #{code}"}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_qr(session) do
    instance = session.phone_number
    url = "#{get_base_url()}/instance/connect/#{instance}"

    case Req.get(url, headers: headers()) do
      {:ok, %{status: 200, body: %{"base64" => base64}}} when is_binary(base64) ->
        {:ok, base64 |> String.split(",") |> List.last()}

      {:ok, %{status: 200}} ->
        {:error, :qr_not_ready}

      _ ->
        {:error, :fetch_failed}
    end
  end

  @impl true
  def get_status(session) do
    instance = session.phone_number
    url = "#{get_base_url()}/instance/connectionState/#{instance}"

    case Req.get(url, headers: headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["instance"]["state"]}

      _ ->
        {:error, "unknown"}
    end
  end

  # --- Helper Functions ---

  defp headers do
    [{"apikey", get_api_key()}]
  end

  defp get_base_url,
    do: Application.get_env(:wa_gate, :whatsapp_engine_url, "http://localhost:8080")

  defp get_api_key, do: Application.get_env(:wa_gate, :whatsapp_engine_api_key)
end
