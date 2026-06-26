defmodule WaGate.Accounts do
  import Ecto.Query, warn: false
  alias WaGate.Repo
  alias WaGate.Accounts.Session

  def list_sessions(user_id) do
    Repo.all(from s in Session, where: s.user_id == ^user_id)
  end

  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  # Dipakai internal (webhook, worker) — tanpa filter user
  def get_session!(id), do: Repo.get!(Session, id)

  # Dipakai LiveView — memastikan session milik user
  def get_user_session!(id, user_id) do
    Repo.get_by!(Session, id: id, user_id: user_id)
  end

  def get_session_by_phone(phone_number) do
    Repo.get_by(Session, phone_number: phone_number)
  end

  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  def create_session_with_instance(attrs, user_id) do
    phone = Map.get(attrs, "phone_number") || Map.get(attrs, :phone_number)

    case WaGate.WhatsApp.Adapters.Evolution.create_instance(phone) do
      {:ok, _} -> create_session(Map.put(attrs, "user_id", user_id))
      {:error, reason} -> {:error, reason}
    end
  end
end
