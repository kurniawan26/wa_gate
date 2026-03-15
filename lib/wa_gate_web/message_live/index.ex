defmodule WaGateWeb.MessageLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    messages = Messaging.list_recent_messages(50)
    {:ok, assign(socket, messages: messages)}
  end

  @impl true
  def handle_info({:new_inbound, _message}, socket) do
    messages = Messaging.list_recent_messages(50)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:message_sent, _message}, socket) do
    messages = Messaging.list_recent_messages(50)
    {:noreply, assign(socket, messages: messages)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-3xl mx-auto">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">Message Feed</h1>
        <span class="text-sm text-gray-400">Live • auto update</span>
      </div>

      <div class="space-y-3">
        <%= if @messages == [] do %>
          <div class="text-center text-gray-400 py-20">Belum ada pesan.</div>
        <% end %>

        <%= for msg <- @messages do %>
          <div class={"flex #{if msg.kind == :outbound, do: "justify-end", else: "justify-start"}"}>
            <div class={"max-w-sm rounded-xl px-4 py-3 shadow-sm #{message_bubble_class(msg)}"}>

              <div class="flex items-center gap-2 mb-1">
                <span class="text-xs font-semibold uppercase tracking-wide opacity-70">
                  <%= if msg.kind == :inbound do %>
                    ← {msg.sender_name || msg.sender_number}
                  <% else %>
                    → {msg.recipient_number}
                  <% end %>
                </span>
                <span class={"text-xs px-1.5 py-0.5 rounded #{status_badge_class(msg)}"}>
                  {message_status(msg)}
                </span>
              </div>

              <p class="text-sm">{message_body(msg)}</p>

              <div class="text-xs opacity-50 mt-1 text-right">
                {format_time(msg.inserted_at)}
                <%= if msg.kind == :outbound && msg.whatsapp_session do %>
                  · via {msg.whatsapp_session.phone_number}
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp message_bubble_class(%{kind: :inbound}), do: "bg-blue-50 border border-blue-100 text-blue-900"
  defp message_bubble_class(%{kind: :outbound, status: "failed"}), do: "bg-red-50 border border-red-100 text-red-900"
  defp message_bubble_class(%{kind: :outbound}), do: "bg-green-50 border border-green-100 text-green-900"

  defp status_badge_class(%{kind: :inbound}), do: "bg-blue-200 text-blue-800"
  defp status_badge_class(%{kind: :outbound, status: "sent"}), do: "bg-green-200 text-green-800"
  defp status_badge_class(%{kind: :outbound, status: "failed"}), do: "bg-red-200 text-red-800"
  defp status_badge_class(%{kind: :outbound}), do: "bg-yellow-200 text-yellow-800"

  defp message_status(%{kind: :inbound}), do: "masuk"
  defp message_status(%{kind: :outbound, status: status}), do: status

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
