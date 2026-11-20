defmodule WaGateWeb.SettingsLive do
  use WaGateWeb, :live_view

  alias WaGate.Auth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Pengaturan", new_api_key: nil)}
  end

  @impl true
  def handle_event("generate_api_key", _params, socket) do
    case Auth.generate_api_key(socket.assigns.current_user) do
      {:ok, key, user} ->
        {:noreply,
         socket
         |> assign(current_user: user, new_api_key: key)
         |> put_flash(:info, "API key baru dibuat. Key lama sudah tidak berlaku.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gagal membuat API key.")}
    end
  end

  def handle_event("revoke_api_key", _params, socket) do
    case Auth.revoke_api_key(socket.assigns.current_user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user, new_api_key: nil)
         |> put_flash(:info, "API key dicabut.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Gagal mencabut API key.")}
    end
  end

  def handle_event("dismiss_key", _params, socket) do
    {:noreply, assign(socket, new_api_key: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl px-4 py-10">
        <h1 class="text-xl font-semibold text-gray-900">Pengaturan</h1>

        <section id="api-key-section" class="mt-6 rounded-2xl border border-gray-200 bg-white p-6">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="text-sm font-semibold text-gray-900">API Key</h2>
              <p class="mt-1 text-sm text-gray-500">
                Dipakai untuk
                <code class="rounded bg-gray-100 px-1 py-0.5 text-xs">POST /api/messages</code>
                dengan header <code class="rounded bg-gray-100 px-1 py-0.5 text-xs">Authorization: Bearer &lt;key&gt;</code>.
              </p>
            </div>
            <%= if @current_user.api_key_hash do %>
              <span class="shrink-0 rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700">
                Aktif
              </span>
            <% else %>
              <span class="shrink-0 rounded-full bg-gray-100 px-2.5 py-1 text-xs font-medium text-gray-500">
                Belum ada
              </span>
            <% end %>
          </div>

          <%= if @new_api_key do %>
            <div id="new-api-key" class="mt-5 rounded-xl border border-amber-200 bg-amber-50 p-4">
              <p class="text-sm font-medium text-amber-900">
                Simpan key ini sekarang. Key tidak akan ditampilkan lagi.
              </p>
              <div class="mt-3 flex gap-2">
                <input
                  id="new-api-key-value"
                  type="text"
                  readonly
                  value={@new_api_key}
                  class="min-w-0 flex-1 rounded-lg border border-amber-200 bg-white px-3 py-2 font-mono text-xs text-gray-800 focus:outline-none"
                />
                <button
                  id="copy-api-key"
                  type="button"
                  phx-hook=".CopyToClipboard"
                  data-target="new-api-key-value"
                  class="rounded-lg bg-gray-900 px-3 py-2 text-xs font-medium text-white transition hover:bg-gray-700"
                >
                  Salin
                </button>
              </div>
              <button
                id="dismiss-api-key"
                type="button"
                phx-click="dismiss_key"
                class="mt-3 text-xs text-amber-800 hover:underline"
              >
                Sudah saya simpan
              </button>
            </div>
          <% else %>
            <%= if @current_user.api_key_prefix do %>
              <p class="mt-5 font-mono text-sm text-gray-700">
                {@current_user.api_key_prefix}<span class="text-gray-400">••••••••••••</span>
              </p>
            <% end %>
          <% end %>

          <div class="mt-6 flex flex-wrap gap-2">
            <button
              id="generate-api-key"
              type="button"
              phx-click="generate_api_key"
              data-confirm={
                @current_user.api_key_hash &&
                  "Key lama akan langsung tidak berlaku dan integrasi yang memakainya akan gagal. Lanjutkan?"
              }
              class="rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white transition hover:bg-gray-700"
            >
              {if @current_user.api_key_hash, do: "Buat ulang API key", else: "Buat API key"}
            </button>
            <%= if @current_user.api_key_hash do %>
              <button
                id="revoke-api-key"
                type="button"
                phx-click="revoke_api_key"
                data-confirm="Cabut API key? Semua integrasi yang memakainya akan berhenti."
                class="rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-red-600 transition hover:bg-red-50"
              >
                Cabut
              </button>
            <% end %>
          </div>
        </section>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyToClipboard">
        export default {
          mounted() {
            this.el.addEventListener("click", () => {
              const input = document.getElementById(this.el.dataset.target)
              if (!input) return
              navigator.clipboard.writeText(input.value).then(() => {
                const label = this.el.textContent
                this.el.textContent = "Tersalin ✓"
                setTimeout(() => (this.el.textContent = label), 1500)
              })
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
