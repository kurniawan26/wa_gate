defmodule WaGate.Auth do
  alias WaGate.Repo
  alias WaGate.Auth.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def get_user_by_api_key(api_key) when is_binary(api_key) do
    Repo.get_by(User, api_key: api_key)
  end

  def register(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def change_user_registration(attrs \\ %{}) do
    User.registration_changeset(%User{}, attrs)
  end
end
