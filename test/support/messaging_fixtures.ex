defmodule WaGate.MessagingFixtures do
  @moduledoc false
  alias WaGate.Repo
  alias WaGate.Auth
  alias WaGate.Accounts.Session

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        "email" => "user#{System.unique_integer([:positive])}@example.com",
        "name" => "Tester",
        "password" => "password123"
      })
      |> Auth.register()

    user
  end

  def session_fixture(user, attrs \\ %{}) do
    %Session{user_id: user.id}
    |> Session.changeset(
      Enum.into(attrs, %{
        phone_number: "62811#{System.unique_integer([:positive])}",
        status: "connected"
      })
    )
    |> Repo.insert!()
  end
end
