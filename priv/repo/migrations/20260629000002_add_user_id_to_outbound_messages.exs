defmodule WaGate.Repo.Migrations.AddUserIdToOutboundMessages do
  use Ecto.Migration

  def change do
    alter table(:outbound_messages) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:outbound_messages, [:user_id])
  end
end
