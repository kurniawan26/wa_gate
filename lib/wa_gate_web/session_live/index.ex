defmodule WaGateWeb.SessionLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Accounts
  alias WaGate.Accounts.Session

  on_mount {WaGateWeb.UserAuth, :require_auth}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    sessions = Accounts.list_sessions(user_id)
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
    user_id = socket.assigns.current_user.id

    case Accounts.create_session_with_instance(params, user_id) do
      {:ok, session} ->
        {:noreply, push_navigate(socket, to: ~p"/sessions/#{session.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = changeset |> to_form(as: "session")
        {:noreply, assign(socket, form: form)}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:noreply, put_flash(socket, :error, "Gagal membuat session Waha: tidak dapat terhubung ke server Waha")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Gagal membuat session Waha: #{inspect(reason)}")}
    end
  end

  defp status_color("connected"), do: "bg-green-100 text-green-800"
  defp status_color("banned"), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-yellow-100 text-yellow-800"
end
