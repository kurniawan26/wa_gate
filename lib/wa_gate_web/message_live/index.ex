defmodule WaGateWeb.MessageLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    {:ok,
     assign(socket,
       contacts: Messaging.list_contacts(),
       show_compose: false,
       compose_mode: :single,
       compose_to: "",
       compose_text: ""
     )}
  end

  @impl true
  def handle_event("open_compose", %{"mode" => mode}, socket) do
    {:noreply,
     assign(socket,
       show_compose: true,
       compose_mode: String.to_existing_atom(mode),
       compose_to: "",
       compose_text: ""
     )}
  end

  def handle_event("close_compose", _params, socket) do
    {:noreply, assign(socket, show_compose: false)}
  end

  def handle_event("update_compose_fields", params, socket) do
    {:noreply,
     assign(socket,
       compose_to: Map.get(params, "to", socket.assigns.compose_to),
       compose_text: Map.get(params, "text", socket.assigns.compose_text)
     )}
  end

  def handle_event("send_compose", _params, socket) do
    %{compose_mode: mode, compose_to: to_raw, compose_text: text} = socket.assigns
    trimmed_text = String.trim(text)

    if trimmed_text != "" do
      recipients =
        case mode do
          :single ->
            [String.trim(to_raw)]

          :bulk ->
            to_raw
            |> String.split(~r/[\n,]/)
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
        end

      Enum.each(recipients, &Messaging.enqueue_message(&1, trimmed_text))
    end

    {:noreply, assign(socket, show_compose: false, compose_to: "", compose_text: "")}
  end

  @impl true
  def handle_info({:new_inbound, _message}, socket) do
    {:noreply, assign(socket, contacts: Messaging.list_contacts())}
  end

  def handle_info({:message_sent, _message}, socket) do
    {:noreply, assign(socket, contacts: Messaging.list_contacts())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <%!-- Header --%>
      <div class="flex justify-between items-center px-6 py-4 border-b border-gray-200 bg-white">
        <h1 class="text-base font-semibold text-gray-800">Inbox</h1>
        <div class="flex items-center gap-3">
          <span class="text-xs text-gray-400 flex items-center gap-1.5">
            <span class="w-1.5 h-1.5 bg-emerald-400 rounded-full inline-block"></span> Live
          </span>
          <button
            phx-click="open_compose"
            phx-value-mode="single"
            class="text-xs bg-gray-800 text-white px-3 py-1.5 rounded-lg hover:bg-gray-700 transition"
          >
            + Kirim Pesan
          </button>
          <button
            phx-click="open_compose"
            phx-value-mode="bulk"
            class="text-xs bg-emerald-600 text-white px-3 py-1.5 rounded-lg hover:bg-emerald-700 transition"
          >
            + Kirim Massal
          </button>
        </div>
      </div>

      <%!-- Compose Modal --%>
      <%= if @show_compose do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4 p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-sm font-semibold text-gray-800">
                <%= if @compose_mode == :single, do: "Kirim Pesan", else: "Kirim Massal" %>
              </h2>
              <button
                phx-click="close_compose"
                class="text-gray-400 hover:text-gray-600 text-lg leading-none"
              >
                ✕
              </button>
            </div>

            <form phx-change="update_compose_fields" class="space-y-3">
              <%= if @compose_mode == :single do %>
                <div>
                  <label class="text-xs text-gray-500 mb-1 block">Nomor Tujuan</label>
                  <input
                    type="text"
                    name="to"
                    value={@compose_to}
                    placeholder="628123456789"
                    class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400"
                  />
                </div>
              <% else %>
                <div>
                  <label class="text-xs text-gray-500 mb-1 block">
                    Nomor Tujuan
                    <span class="text-gray-400">(satu per baris atau pisahkan dengan koma)</span>
                  </label>
                  <textarea
                    name="to"
                    placeholder={"628111111111\n628222222222\n628333333333"}
                    rows="4"
                    class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400 resize-none"
                  >{@compose_to}</textarea>
                </div>
              <% end %>

              <div>
                <label class="text-xs text-gray-500 mb-1 block">Pesan</label>
                <textarea
                  name="text"
                  placeholder="Ketik pesan..."
                  rows="3"
                  class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400 resize-none"
                >{@compose_text}</textarea>
              </div>
            </form>

            <div class="flex justify-end gap-2 pt-3">
              <button
                phx-click="close_compose"
                class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2"
              >
                Batal
              </button>
              <button
                phx-click="send_compose"
                disabled={String.trim(@compose_to) == "" or String.trim(@compose_text) == ""}
                class="bg-gray-800 text-white text-sm px-5 py-2 rounded-xl hover:bg-gray-700 disabled:opacity-30 disabled:cursor-not-allowed transition"
              >
                Kirim
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Contact List --%>
      <div class="divide-y divide-gray-100 bg-white">
        <%= if @contacts == [] do %>
          <div class="text-center text-gray-400 text-sm py-20">Belum ada percakapan.</div>
        <% end %>

        <%= for contact <- @contacts do %>
          <.link
            navigate={~p"/messages/#{contact.number}"}
            class="flex items-center gap-4 px-6 py-4 hover:bg-gray-50 transition"
          >
            <div class="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-sm font-medium text-gray-500 shrink-0">
              {String.first(contact.number)}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-baseline justify-between gap-2">
                <span class="text-sm font-medium text-gray-800 truncate">
                  {contact.name || contact.number}
                </span>
                <span class="text-xs text-gray-400 shrink-0">{format_time(contact.last_at)}</span>
              </div>
              <%= if contact.name do %>
                <p class="text-xs text-gray-400">{contact.number}</p>
              <% end %>
              <p class="text-xs text-gray-500 truncate mt-0.5">{contact.preview}</p>
            </div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_time(nil), do: ""

  defp format_time(dt) do
    dt
    |> NaiveDateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end
end
