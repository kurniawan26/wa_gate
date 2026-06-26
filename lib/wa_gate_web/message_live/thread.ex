defmodule WaGateWeb.MessageLive.Thread do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  on_mount {WaGateWeb.UserAuth, :require_auth}

  @impl true
  def mount(%{"number" => number}, _session, socket) do
    user_id = socket.assigns.current_user.id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    {:ok,
     assign(socket,
       number: number,
       messages: Messaging.list_thread(number, user_id),
       reply_text: ""
     )}
  end

  @impl true
  def handle_event("update_reply_text", %{"text" => value}, socket) do
    {:noreply, assign(socket, reply_text: value)}
  end

  def handle_event("send_reply", %{"text" => text}, socket) do
    trimmed = String.trim(text)

    if trimmed != "" do
      Messaging.enqueue_message(socket.assigns.number, trimmed)
    end

    {:noreply, assign(socket, reply_text: "")}
  end

  @impl true
  def handle_info({:new_inbound, _message}, socket) do
    user_id = socket.assigns.current_user.id
    {:noreply, assign(socket, messages: Messaging.list_thread(socket.assigns.number, user_id))}
  end

  def handle_info({:message_sent, _message}, socket) do
    user_id = socket.assigns.current_user.id
    {:noreply, assign(socket, messages: Messaging.list_thread(socket.assigns.number, user_id))}
  end

  defp contact_name(messages, fallback) do
    messages
    |> Enum.find(&(&1.kind == :inbound))
    |> case do
      %{sender_name: name} when is_binary(name) and name != "" -> name
      _ -> fallback
    end
  end

  defp bubble_class(%{kind: :inbound}),
    do: "bg-white border border-gray-200 text-gray-800 rounded-tl-sm"

  defp bubble_class(%{kind: :outbound, status: "failed"}),
    do: "bg-white border border-red-200 text-gray-800 rounded-tr-sm"

  defp bubble_class(%{kind: :outbound}), do: "bg-gray-800 text-white rounded-tr-sm"

  defp status_text_class(%{kind: :outbound, status: "failed"}), do: "text-red-400"
  defp status_text_class(_), do: "text-gray-400"

  defp status_label(%{kind: :inbound}), do: ""
  defp status_label(%{kind: :outbound, status: "sent"}), do: "✓ terkirim"
  defp status_label(%{kind: :outbound, status: "failed"}), do: "✕ gagal"
  defp status_label(%{kind: :outbound, status: "pending"}), do: "· menunggu"
  defp status_label(_), do: ""

  defp message_body(%{kind: :inbound, body: body}), do: body || "(non-text)"
  defp message_body(%{kind: :outbound, payload: payload}), do: payload

  defp format_time(nil), do: ""

  defp format_time(dt) do
    dt
    |> NaiveDateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end
end
