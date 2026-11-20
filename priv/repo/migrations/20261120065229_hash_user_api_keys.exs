defmodule WaGate.Repo.Migrations.HashUserApiKeys do
  use Ecto.Migration

  # API key tidak lagi disimpan plaintext. Key lama tetap berlaku karena
  # lookup dilakukan dengan membandingkan SHA-256 dari token yang dikirim.
  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    alter table(:users) do
      add :api_key_hash, :string
      add :api_key_prefix, :string
    end

    flush()

    execute """
    UPDATE users
    SET api_key_hash = encode(digest(api_key, 'sha256'), 'hex'),
        api_key_prefix = left(api_key, 8)
    WHERE api_key IS NOT NULL
    """

    drop_if_exists index(:users, [:api_key])

    alter table(:users) do
      remove :api_key
    end

    create unique_index(:users, [:api_key_hash])
  end

  def down do
    # Plaintext key tidak bisa dipulihkan; user perlu membuat key baru.
    drop_if_exists index(:users, [:api_key_hash])

    alter table(:users) do
      remove :api_key_hash
      remove :api_key_prefix
      add :api_key, :string
    end

    create unique_index(:users, [:api_key])
  end
end
