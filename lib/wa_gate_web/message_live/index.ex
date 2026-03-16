defmodule WaGateWeb.MessageLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    socket =
      socket
      |> assign(
        contacts: Messaging.list_contacts(),
        show_compose: false,
        compose_mode: :single,
        compose_to: "",
        compose_text: "",
        bulk_csv: "",
        bulk_template: "",
        bulk_preview: []
      )
      |> allow_upload(:csv_file, accept: ~w(.csv text/csv), max_entries: 1, auto_upload: true)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_compose", %{"mode" => mode}, socket) do
    {:noreply,
     assign(socket,
       show_compose: true,
       compose_mode: String.to_existing_atom(mode),
       compose_to: "",
       compose_text: "",
       bulk_csv: "",
       bulk_template: "",
       bulk_preview: []
     )}
  end

  def handle_event("close_compose", _params, socket) do
    {:noreply, assign(socket, show_compose: false)}
  end

  # Single mode
  def handle_event("update_compose_fields", params, socket) do
    {:noreply,
     assign(socket,
       compose_to: Map.get(params, "to", socket.assigns.compose_to),
       compose_text: Map.get(params, "text", socket.assigns.compose_text)
     )}
  end

  # Dipanggil saat file dipilih atau template berubah (satu form)
  def handle_event("update_bulk_fields", params, socket) do
    template = Map.get(params, "template", socket.assigns.bulk_template)
    socket = socket |> maybe_consume_csv() |> assign(bulk_template: template)
    preview = build_preview(socket.assigns.bulk_csv, socket.assigns.bulk_template)
    {:noreply, assign(socket, bulk_preview: preview)}
  end

  def handle_event("send_compose", _params, socket) do
    case socket.assigns.compose_mode do
      :single ->
        text = String.trim(socket.assigns.compose_text)
        to = String.trim(socket.assigns.compose_to)
        if text != "" and to != "", do: Messaging.enqueue_message(to, text)

      :bulk ->
        Enum.each(socket.assigns.bulk_preview, fn %{number: number, message: message} ->
          Messaging.enqueue_message(number, message)
        end)
    end

    {:noreply, assign(socket, show_compose: false)}
  end

  @impl true
  def handle_info({:new_inbound, _message}, socket) do
    {:noreply, assign(socket, contacts: Messaging.list_contacts())}
  end

  def handle_info({:message_sent, _message}, socket) do
    {:noreply, assign(socket, contacts: Messaging.list_contacts())}
  end

  # ── Upload helpers ───────────────────────────────────────────────────────────

  defp maybe_consume_csv(socket) do
    case socket.assigns.uploads.csv_file.entries do
      [%{done?: true}] ->
        [content] =
          consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
            {:ok, File.read!(path)}
          end)

        preview = build_preview(content, socket.assigns.bulk_template)
        assign(socket, bulk_csv: content, bulk_preview: preview)

      _ ->
        socket
    end
  end

  # ── CSV helpers ─────────────────────────────────────────────────────────────

  defp build_preview(csv, template) do
    if String.trim(csv) == "" or String.trim(template) == "" do
      []
    else
      rows = parse_csv(csv)

      rows
      |> Enum.map(fn row ->
        %{
          number: Map.get(row, "number", ""),
          name: Map.get(row, "name", ""),
          message: interpolate(template, row)
        }
      end)
      |> Enum.reject(&(&1.number == ""))
    end
  end

  defp parse_csv(csv) do
    lines =
      csv
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [] -> []
      [_header_only] -> []
      [header_line | data_lines] ->
        headers = header_line |> String.split(",") |> Enum.map(&String.trim/1)

        Enum.map(data_lines, fn line ->
          values = line |> String.split(",") |> Enum.map(&String.trim/1)
          headers |> Enum.zip(values) |> Map.new()
        end)
    end
  end

  defp interpolate(template, row) do
    Enum.reduce(row, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end

  # ── Render ───────────────────────────────────────────────────────────────────

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

      <%!-- Single Compose Modal --%>
      <%= if @show_compose and @compose_mode == :single do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div class="bg-white rounded-2xl shadow-xl w-full max-w-md mx-4 p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-sm font-semibold text-gray-800">Kirim Pesan</h2>
              <button phx-click="close_compose" class="text-gray-400 hover:text-gray-600 text-lg leading-none">
                ✕
              </button>
            </div>

            <form phx-change="update_compose_fields" class="space-y-3">
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
              <div>
                <label class="text-xs text-gray-500 mb-1 block">Pesan</label>
                <textarea
                  name="text"
                  placeholder="Ketik pesan..."
                  rows="5"
                  class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400 resize-none"
                >{@compose_text}</textarea>
              </div>
            </form>

            <div class="flex justify-end gap-2 pt-3">
              <button phx-click="close_compose" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">
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

      <%!-- Bulk CSV Compose Modal --%>
      <%= if @show_compose and @compose_mode == :bulk do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div class="bg-white rounded-2xl shadow-xl w-full max-w-3xl flex flex-col max-h-[90vh]">
            <%!-- Modal Header --%>
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100 shrink-0">
              <div>
                <h2 class="text-sm font-semibold text-gray-800">Kirim Massal (CSV)</h2>
                <p class="text-xs text-gray-400 mt-0.5">
                  Kolom wajib: <code class="bg-gray-100 px-1 rounded">number</code>.
                  Gunakan <code class="bg-gray-100 px-1 rounded">{"{{nama_kolom}}"}</code> di template.
                </p>
              </div>
              <button phx-click="close_compose" class="text-gray-400 hover:text-gray-600 text-lg leading-none ml-4">
                ✕
              </button>
            </div>

            <%!-- Modal Body --%>
            <div class="flex-1 overflow-y-auto px-6 py-4">
              <form phx-change="update_bulk_fields" class="space-y-4">
                <%!-- File Upload --%>
                <div>
                  <label class="text-xs text-gray-500 mb-1 block">File CSV Penerima</label>
                  <label class="flex flex-col items-center justify-center w-full h-20 border-2 border-dashed border-gray-200 rounded-xl cursor-pointer bg-gray-50 hover:bg-gray-100 transition">
                    <.live_file_input upload={@uploads.csv_file} class="hidden" />
                    <%= case @uploads.csv_file.entries do %>
                      <% [entry] -> %>
                        <div class="flex items-center gap-2 pointer-events-none">
                          <%= if entry.done? do %>
                            <span class="text-xs text-emerald-600 font-medium">✓ {entry.client_name}</span>
                          <% else %>
                            <span class="text-xs text-gray-500">{entry.client_name} — {entry.progress}%</span>
                          <% end %>
                        </div>
                      <% [] -> %>
                        <div class="text-center pointer-events-none">
                          <p class="text-xs text-gray-400">Klik atau seret file .csv ke sini</p>
                          <p class="text-xs text-gray-300 mt-0.5">Kolom wajib: number, name</p>
                        </div>
                    <% end %>
                  </label>
                </div>

                <%!-- Template Input --%>
                <div>
                  <label class="text-xs text-gray-500 mb-1 block">
                    Template Pesan
                    <span class="text-gray-400 font-normal">— gunakan {"{{name}}"}, {"{{number}}"}, dll.</span>
                  </label>
                  <textarea
                    name="template"
                    rows="8"
                    placeholder={"Dear {{name}},\n\nTerima kasih sudah memilih Dicoding..."}
                    class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm text-gray-800 bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-white transition placeholder:text-gray-400 resize-none"
                  >{@bulk_template}</textarea>
                </div>
              </form>

              <%!-- Live Preview --%>
              <%= if @bulk_preview != [] do %>
                <div class="mt-4">
                  <div class="flex items-center justify-between mb-2">
                    <p class="text-xs font-medium text-gray-500">
                      Preview — {length(@bulk_preview)} penerima
                    </p>
                  </div>
                  <div class="space-y-2 max-h-64 overflow-y-auto pr-1">
                    <%= for {item, idx} <- Enum.with_index(@bulk_preview) do %>
                      <div class="border border-gray-100 rounded-xl p-3 bg-gray-50">
                        <div class="flex items-center gap-2 mb-1.5">
                          <span class="text-xs text-gray-400 font-mono w-4 text-right shrink-0">
                            {idx + 1}
                          </span>
                          <span class="text-xs font-medium text-gray-700">{item.name || item.number}</span>
                          <%= if item.name != "" do %>
                            <span class="text-xs text-gray-400 font-mono">{item.number}</span>
                          <% end %>
                        </div>
                        <p class="text-xs text-gray-600 whitespace-pre-wrap leading-relaxed ml-6">
                          {item.message}
                        </p>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <%!-- Modal Footer --%>
            <div class="flex items-center justify-between px-6 py-4 border-t border-gray-100 shrink-0">
              <p class="text-xs text-gray-400">
                <%= cond do %>
                  <% @bulk_preview == [] and @bulk_csv != "" -> %>
                    Isi template untuk melihat preview.
                  <% @bulk_preview == [] -> %>
                    Tempel data CSV untuk memulai.
                  <% true -> %>
                    {length(@bulk_preview)} pesan siap dikirim.
                <% end %>
              </p>
              <div class="flex gap-2">
                <button phx-click="close_compose" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">
                  Batal
                </button>
                <button
                  phx-click="send_compose"
                  disabled={@bulk_preview == []}
                  class="bg-emerald-600 text-white text-sm px-5 py-2 rounded-xl hover:bg-emerald-700 disabled:opacity-30 disabled:cursor-not-allowed transition"
                >
                  Kirim {if @bulk_preview != [], do: "(#{length(@bulk_preview)})", else: ""}
                </button>
              </div>
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
