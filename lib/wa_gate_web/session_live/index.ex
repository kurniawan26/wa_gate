defmodule WaGateWeb.SessionLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Accounts
  alias WaGate.Accounts.Session

  @impl true
  def mount(_params, _session, socket) do
    sessions = Accounts.list_sessions()
    {:ok, assign(socket, sessions: sessions, show_form: false, form: nil)}
  end

  @impl true
  def handle_event("new", _params, socket) do
    form = Accounts.change_session(%Session{}) |> to_form(as: "session")
    {:noreply, assign(socket, show_form: true, form: form)}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, show_form: false, form: nil)}
  end

  def handle_event("validate", %{"session" => params}, socket) do
    form = Accounts.change_session(%Session{}, params) |> to_form(as: "session")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("create", %{"session" => params}, socket) do
    case Accounts.create_session_with_instance(params) do
      {:ok, session} ->
        {:noreply, push_navigate(socket, to: ~p"/sessions/#{session.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = changeset |> to_form(as: "session")
        {:noreply, assign(socket, form: form)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal membuat instance Evolution: #{reason}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold">WhatsApp Gateway Sessions</h1>
        <button phx-click="new" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
          + Tambah Session
        </button>
      </div>

      <%= if @show_form do %>
        <div class="border rounded-lg p-6 bg-white mb-6 shadow-sm">
          <h2 class="text-lg font-semibold mb-4">Tambah Session Baru</h2>
          <.form for={@form} phx-submit="create" phx-change="validate">
            <div class="mb-3">
              <label class="block text-sm font-medium mb-1">Nama Session</label>
              <.input field={@form[:name]} placeholder="Contoh: CS Center" />
            </div>
            <div class="mb-3">
              <label class="block text-sm font-medium mb-1">Nomor WhatsApp</label>
              <.input field={@form[:phone_number]} placeholder="628123456789" />
            </div>
            <div class="mb-4">
              <label class="block text-sm font-medium mb-1">Maks Pesan / Hari</label>
              <.input field={@form[:max_daily_messages]} type="number" value="100" />
            </div>
            <div class="flex gap-2">
              <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
                Simpan & Scan QR
              </button>
              <button type="button" phx-click="cancel" class="bg-gray-200 px-4 py-2 rounded hover:bg-gray-300">
                Batal
              </button>
            </div>
          </.form>
        </div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <%= for session <- @sessions do %>
          <div class="border p-4 rounded-lg shadow-sm bg-white">
            <h2 class="font-semibold text-lg">{session.name}</h2>
            <p class="text-sm text-gray-500">{session.phone_number}</p>
            <div class="mt-2">
              <span class={"px-2 py-1 rounded text-xs #{status_color(session.status)}"}>
                {String.upcase(session.status)}
              </span>
            </div>
            <div class="mt-3 text-sm text-gray-600">
              Pesan Hari Ini: {session.messages_sent_today} / {session.max_daily_messages}
            </div>
            <div class="mt-4">
              <.link navigate={~p"/sessions/#{session.id}"} class="text-blue-500 hover:underline text-sm">
                Manage & Scan QR →
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_color("connected"), do: "bg-green-100 text-green-800"
  defp status_color("banned"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-yellow-100 text-yellow-800"
end
