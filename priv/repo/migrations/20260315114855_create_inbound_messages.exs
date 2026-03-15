defmodule WaGate.Repo.Migrations.CreateInboundMessages do
  use Ecto.Migration

  def change do
    create table(:inbound_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_id, :string, null: false
      add :sender_number, :string, null: false
      add :sender_name, :string
      add :body, :text
      add :message_type, :string, null: false
      add :raw_payload, :map, null: false

      add :whatsapp_session_id,
          references(:whatsapp_sessions, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:inbound_messages, [:external_id])
    create index(:inbound_messages, [:sender_number])
    create index(:inbound_messages, [:whatsapp_session_id])
  end
end
