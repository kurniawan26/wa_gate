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

end
