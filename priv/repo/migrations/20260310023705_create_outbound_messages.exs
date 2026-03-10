defmodule WaGate.Repo.Migrations.CreateOutboundMessages do
  use Ecto.Migration

  def change do
    create table(:outbound_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :recipient_number, :string, null: false
      add :payload, :text, null: false

      add :status, :string, default: "pending", null: false

      add :whatsapp_session_id,
          references(:whatsapp_sessions, type: :binary_id, on_delete: :nilify_all)

      add :error_reason, :string
      add :retry_count, :integer, default: 0

      timestamps()
    end

    create index(:outbound_messages, [:status])
    create index(:outbound_messages, [:whatsapp_session_id])
  end
end
