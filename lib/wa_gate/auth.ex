defmodule WaGate.Auth do
  alias WaGate.Repo
  alias WaGate.Auth.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @api_key_prefix "wag_"

  @doc "Mencari user berdasarkan API key (disimpan sebagai hash SHA-256)."
  def get_user_by_api_key(api_key) when is_binary(api_key) and api_key != "" do
    Repo.get_by(User, api_key_hash: hash_api_key(api_key))
  end

  def get_user_by_api_key(_), do: nil

  @doc """
  Membuat API key baru untuk user (key lama otomatis tidak berlaku).
  Key plaintext hanya dikembalikan sekali di sini dan tidak disimpan.
  """
  def generate_api_key(%User{} = user) do
    key = @api_key_prefix <> (:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower))

    user
    |> Ecto.Changeset.change(
      api_key_hash: hash_api_key(key),
      api_key_prefix: String.slice(key, 0, 12)
    )
    |> Repo.update()
    |> case do
      {:ok, user} -> {:ok, key, user}
      error -> error
    end
  end

  def revoke_api_key(%User{} = user) do
    user
    |> Ecto.Changeset.change(api_key_hash: nil, api_key_prefix: nil)
    |> Repo.update()
  end

  defp hash_api_key(key), do: :crypto.hash(:sha256, key) |> Base.encode16(case: :lower)

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
