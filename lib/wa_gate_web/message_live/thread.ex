defmodule WaGateWeb.MessageLive.Thread do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  @impl true
  def mount(%{"number" => number}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    {:ok,
     assign(socket,
       number: number,
       messages: Messaging.list_thread(number),
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
    {:noreply, assign(socket, messages: Messaging.list_thread(socket.assigns.number))}
  end

  def handle_info({:message_sent, _message}, socket) do
    {:noreply, assign(socket, messages: Messaging.list_thread(socket.assigns.number))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen max-w-2xl mx-auto bg-gray-50">
      <%!-- Header --%>
      <div class="flex items-center gap-4 px-6 py-4 border-b border-gray-200 bg-white shrink-0">
        <.link navigate={~p"/messages"} class="text-gray-400 hover:text-gray-600 text-lg leading-none">
          ←
        </.link>
        <div class="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center text-sm font-medium text-gray-500">
          {String.first(@number)}
        </div>
        <div>
          <p class="text-sm font-semibold text-gray-800">{contact_name(@messages, @number)}</p>
          <%= if contact_name(@messages, @number) != @number do %>
            <p class="text-xs text-gray-400">{@number}</p>
          <% end %>
        </div>
        <span class="ml-auto text-xs text-gray-400 flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 bg-emerald-400 rounded-full inline-block"></span> Live
        </span>
      </div>

      <%!-- Thread --%>
      <div class="flex-1 overflow-y-auto px-6 py-5 space-y-2">
        <%= if @messages == [] do %>
          <div class="text-center text-gray-400 text-sm py-20">Belum ada pesan.</div>
        <% end %>

        <%= for msg <- @messages do %>
          <div class={"flex #{if msg.kind == :outbound, do: "justify-end", else: "justify-start"}"}>
            <div class={"max-w-sm #{if msg.kind == :outbound, do: "items-end", else: "items-start"}"}>
              <div class={"rounded-2xl px-4 py-2.5 #{bubble_class(msg)}"}>
                <p class="text-sm leading-relaxed">{message_body(msg)}</p>
              </div>
              <div class={"flex items-center gap-2 mt-1 #{if msg.kind == :outbound, do: "justify-end"}"}>
                <span class="text-xs text-gray-400">{format_time(msg.inserted_at)}</span>
                <span class={"text-xs #{status_text_class(msg)}"}>{status_label(msg)}</span>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Reply Bar --%>
      <div class="border-t border-gray-200 bg-white px-4 pt-3 pb-4 shrink-0">
        <form phx-change="update_reply_text" phx-submit="send_reply" class="flex gap-2">
          <input
            type="text"
            name="text"
            value={@reply_text}
            placeholder="Ketik pesan..."
            class="flex-1 border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400"
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
    </div>
    """
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
