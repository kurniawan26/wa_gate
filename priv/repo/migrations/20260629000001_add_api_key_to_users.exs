defmodule WaGate.Repo.Migrations.AddApiKeyToUsers do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    alter table(:users) do
      add :api_key, :string
    end

    create unique_index(:users, [:api_key])

    execute "UPDATE users SET api_key = encode(gen_random_bytes(32), 'hex') WHERE api_key IS NULL"
  end

  def down do
    drop index(:users, [:api_key])

    alter table(:users) do
      remove :api_key
    end
  end
end
