defmodule WaGate.WhatsApp.Adapters.Waha do
  @behaviour WaGate.WhatsApp.EngineBehaviour

  @impl true
  def send_message(session, to, text) do
    url = "#{get_base_url()}/api/sendText"

    case Req.post(url,
           json: %{"session" => session.phone_number, "chatId" => to_chat_id(to), "text" => text},
           headers: headers()
         ) do
      {:ok, %{status: status}} when status in [200, 201] -> {:ok, %{}}
      {:ok, %{status: 401}} -> {:error, :unauthorized}
      {:ok, %{status: 422}} -> {:error, :session_failed}
      {:ok, %{status: code}} -> {:error, "Waha returned status #{code}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def update_presence(session, to, presence) do
    url = "#{get_base_url()}/api/#{session.phone_number}/presence"
    value = if presence == :composing, do: "typing", else: "paused"

    Req.post(url,
      json: %{"chatId" => to_chat_id(to), "presence" => value},
      headers: headers()
    )

    :ok
  end

  @impl true
  def get_status(session) do
    url = "#{get_base_url()}/api/sessions/#{session.phone_number}"

    case Req.get(url, headers: headers()) do
      {:ok, %{status: 200, body: %{"status" => status}}} ->
        {:ok, waha_to_evolution_state(status)}

      _ ->
        {:error, "unknown"}
    end
  end

  def create_instance(phone_number) do
    url = "#{get_base_url()}/api/sessions"
    webhook_url = Application.get_env(:wa_gate, :webhook_url, "http://localhost:4000/api/webhooks/whatsapp")

    case Req.post(url,
           json: %{
             "name" => phone_number,
             "start" => true,
             "config" => %{
               "webhooks" => [
                 %{"url" => webhook_url, "events" => ["message", "session.status"]}
               ]
             }
           },
           headers: headers()
         ) do
      {:ok, %{status: status}} when status in [200, 201] -> {:ok, :created}
      {:ok, %{status: 422}} -> {:ok, :already_exists}
      {:ok, %{status: code}} -> {:error, "Waha returned #{code}"}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_qr(session) do
    url = "#{get_base_url()}/api/#{session.phone_number}/auth/qr"

    case Req.get(url, headers: headers() ++ [{"accept", "application/json"}]) do
      {:ok, %{status: 200, body: %{"data" => data}}} when is_binary(data) ->
        {:ok, data}

      {:ok, %{status: 200}} ->
        {:error, :qr_not_ready}

      _ ->
        {:error, :fetch_failed}
    end
  end

  # --- Helpers ---

  defp to_chat_id(number) do
    if String.contains?(number, "@"), do: number, else: "#{number}@c.us"
  end

  defp waha_to_evolution_state("WORKING"), do: "open"
  defp waha_to_evolution_state(status), do: String.downcase(status)

  defp headers do
    [{"X-Api-Key", get_api_key()}]
  end

  defp get_base_url,
    do: Application.get_env(:wa_gate, :whatsapp_engine_url, "http://localhost:3000")

  defp get_api_key, do: Application.get_env(:wa_gate, :whatsapp_engine_api_key)
end
