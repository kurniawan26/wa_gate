defmodule WaGateWeb.SessionLive.Show do
  use WaGateWeb, :live_view
  alias WaGate.Accounts

  @qr_refresh_interval 30_000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    session = Accounts.get_session!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "session:#{session.id}")
      schedule_qr_refresh(session)
    end

    qr_code = fetch_qr_code(session)

    {:ok, assign(socket, session: session, qr_code: qr_code)}
  end

  @impl true
  def handle_event("refresh_qr", _params, socket) do
    qr_code = fetch_qr_code(socket.assigns.session)
    {:noreply, assign(socket, qr_code: qr_code)}
  end

  def handle_event("sync_status", _params, socket) do
    session = socket.assigns.session

    case WaGate.WhatsApp.Adapters.Evolution.get_status(session) do
      {:ok, "open"} ->
        {:ok, updated} = Accounts.update_session(session, %{status: "connected"})
        Phoenix.PubSub.broadcast(WaGate.PubSub, "session:#{updated.id}", :connected)
        {:noreply, assign(socket, session: updated, qr_code: nil)}

      {:ok, state} ->
        {:noreply, put_flash(socket, :info, "Status Evolution: #{state}. Belum terhubung.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gagal mengambil status dari Evolution.")}
    end
  end

  @impl true
  def handle_info(:connected, socket) do
    session = Accounts.get_session!(socket.assigns.session.id)
    {:noreply, assign(socket, session: session, qr_code: nil)}
  end

  def handle_info(:refresh_qr, socket) do
    session = socket.assigns.session

    if session.status != "connected" do
      qr_code = fetch_qr_code(session)
      schedule_qr_refresh(session)
      {:noreply, assign(socket, qr_code: qr_code)}
    else
      {:noreply, socket}
    end
  end

  defp fetch_qr_code(session) do
    case WaGate.WhatsApp.Adapters.Evolution.fetch_qr(session) do
      {:ok, base64} -> base64
      {:error, _} -> nil
    end
  end

  defp schedule_qr_refresh(session) do
    if session.status != "connected" do
      Process.send_after(self(), :refresh_qr, @qr_refresh_interval)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <.link navigate={~p"/sessions"} class="text-sm text-gray-500">← Kembali</.link>
      <h1 class="text-3xl font-bold mt-2">{@session.name}</h1>
      <p class="text-gray-500 text-sm">{@session.phone_number}</p>

      <div class="mt-8 flex flex-col items-center border p-10 bg-gray-50 rounded-xl">
        <%= if @session.status == "connected" do %>
          <div class="text-center">
            <div class="text-green-500 text-5xl mb-4">✅</div>
            <p class="text-xl font-medium">Nomor Sudah Terhubung</p>
            <p class="text-sm text-gray-500 mt-2">
              Pesan terkirim hari ini: {@session.messages_sent_today} / {@session.max_daily_messages}
            </p>
          </div>
        <% else %>
          <p class="mb-4 text-gray-600">Silakan scan QR Code dengan aplikasi WhatsApp Anda:</p>
          <%= if @qr_code do %>
            <img src={"data:image/png;base64,#{@qr_code}"} class="border-4 border-white shadow-lg" />
          <% else %>
            <div class="animate-pulse bg-gray-200 w-64 h-64 flex items-center justify-center text-gray-400">
              Memuat QR Code...
            </div>
          <% end %>
          <div class="flex gap-3 mt-6">
            <button phx-click="refresh_qr" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
              Refresh QR
            </button>
            <button phx-click="sync_status" class="bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700">
              Cek Status
            </button>
          </div>
          <p class="text-xs text-gray-400 mt-3">QR otomatis diperbarui tiap 30 detik</p>
        <% end %>
      </div>
    </div>
    """
  end
end
