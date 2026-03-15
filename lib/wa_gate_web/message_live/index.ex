defmodule WaGateWeb.MessageLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    messages = Messaging.list_recent_messages(50)
    {:ok, assign(socket, messages: messages, reply_to: nil, reply_text: "")}
  end

  @impl true
  def handle_event("set_reply_target", %{"number" => number}, socket) do
    {:noreply, assign(socket, reply_to: number, reply_text: "")}
  end

  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, reply_to: nil, reply_text: "")}
  end

  def handle_event("update_reply_text", %{"text" => value}, socket) do
    {:noreply, assign(socket, reply_text: value)}
  end

  def handle_event("send_reply", %{"text" => text}, socket) do
    to = socket.assigns.reply_to

    if String.trim(text) != "" and not is_nil(to) do
      Messaging.enqueue_message(to, String.trim(text))
    end

    {:noreply, assign(socket, reply_text: "")}
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
    <div class="flex flex-col h-screen max-w-3xl mx-auto bg-gray-50">
      <%!-- Header --%>
      <div class="flex justify-between items-center px-6 py-4 border-b border-gray-200 bg-white">
        <h1 class="text-base font-semibold text-gray-800">Message Feed</h1>
        <span class="text-xs text-gray-400 flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 bg-emerald-400 rounded-full inline-block"></span> Live
        </span>
      </div>

      <%!-- Feed --%>
      <div class="flex-1 overflow-y-auto px-6 py-5 space-y-2">
        <%= if @messages == [] do %>
          <div class="text-center text-gray-400 text-sm py-20">Belum ada pesan.</div>
        <% end %>

        <%= for msg <- @messages do %>
          <div class={"flex #{if msg.kind == :outbound, do: "justify-end", else: "justify-start"}"}>
            <div class={"max-w-sm #{bubble_class(msg)}"}>
              <p class={"text-xs text-gray-400 mb-1 " <> if(msg.kind == :outbound, do: "text-right", else: "")}>
                <%= if msg.kind == :inbound do %>
                  {msg.sender_name || msg.sender_number}
                <% else %>
                  {msg.recipient_number}
                <% end %>
              </p>

              <div class={"rounded-2xl px-4 py-2.5 #{bubble_inner_class(msg)}"}>
                <p class="text-sm leading-relaxed">{message_body(msg)}</p>
              </div>

              <div class={"flex items-center gap-2 mt-1 #{if msg.kind == :outbound, do: "justify-end"}"}>
                <span class="text-xs text-gray-400">{format_time(msg.inserted_at)}</span>
                <span class={"text-xs #{status_text_class(msg)}"}>
                  {status_label(msg)}
                </span>
                <%= if msg.kind == :inbound do %>
                  <button
                    phx-click="set_reply_target"
                    phx-value-number={msg.sender_number}
                    class="text-xs text-gray-400 hover:text-gray-600 ml-1"
                  >
                    Balas
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Reply Bar --%>
      <%= if @reply_to do %>
        <div class="border-t border-gray-200 bg-white px-4 pt-3 pb-4">
          <div class="flex items-center mb-2">
            <span class="text-xs text-gray-400">
              Membalas <span class="text-gray-600 font-medium">{@reply_to}</span>
            </span>
            <button
              phx-click="cancel_reply"
              class="ml-auto text-gray-300 hover:text-gray-500 text-sm leading-none"
            >
              ✕
            </button>
          </div>
          <form phx-change="update_reply_text" phx-submit="send_reply" class="flex gap-2">
            <input
              type="text"
              name="text"
              value={@reply_text}
              placeholder="Ketik pesan..."
              class="flex-1 border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400"
              autofocus
            />
            <button
              type="submit"
              disabled={String.trim(@reply_text) == ""}
              class="bg-gray-800 text-white px-4 py-2 rounded-xl text-sm hover:bg-gray-700 disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              Kirim
            </button>
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  defp bubble_class(%{kind: :inbound}), do: "items-start"
  defp bubble_class(%{kind: :outbound}), do: "items-end"

  defp bubble_inner_class(%{kind: :inbound}),
    do: "bg-white border border-gray-200 text-gray-800 rounded-tl-sm"

  defp bubble_inner_class(%{kind: :outbound, status: "failed"}),
    do: "bg-white border border-red-200 text-gray-800 rounded-tr-sm"

  defp bubble_inner_class(%{kind: :outbound}), do: "bg-gray-800 text-white rounded-tr-sm"

  defp status_text_class(%{kind: :outbound, status: "failed"}), do: "text-red-400"
  defp status_text_class(%{kind: :outbound, status: "sent"}), do: "text-gray-400"
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
