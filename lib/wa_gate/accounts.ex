defmodule WaGate.Accounts do
  import Ecto.Query, warn: false
  alias WaGate.Repo
  alias WaGate.Accounts.Session

  def list_sessions do
    Repo.all(Session)
  end

  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def get_session!(id), do: Repo.get!(Session, id)

  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end
end
