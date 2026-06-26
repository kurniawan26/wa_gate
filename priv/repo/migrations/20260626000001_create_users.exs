defmodule WaGate.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string, null: false
      add :password_hash, :string, null: false
      add :enc_salt, :string, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:users, [:email])
  end
end
