defmodule WaGate.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :enc_salt, :string

    has_many :whatsapp_sessions, WaGate.Accounts.Session, foreign_key: :user_id

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :name, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "harus berformat email valid")
    |> validate_length(:password, min: 8, message: "minimal 8 karakter")
    |> update_change(:email, &String.downcase/1)
    |> unique_constraint(:email, message: "email sudah terdaftar")
    |> put_enc_salt()
    |> hash_password()
  end

  defp put_enc_salt(%{valid?: true} = changeset) do
    salt = :crypto.strong_rand_bytes(16) |> Base.encode64()
    put_change(changeset, :enc_salt, salt)
  end

  defp put_enc_salt(changeset), do: changeset

  defp hash_password(%{valid?: true} = changeset) do
    password = get_change(changeset, :password)
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset
end
