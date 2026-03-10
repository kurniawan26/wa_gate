defmodule WaGate.Repo.Migrations.CreateWhatsappSessions do
  use Ecto.Migration

  def change do
    create table(:whatsapp_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :phone_number, :string, null: false
      add :name, :string

      add :status, :string, default: "initial", null: false

      add :auth_data, :map, default: %{}

      add :max_daily_messages, :integer, default: 100
      add :messages_sent_today, :integer, default: 0
      add :last_used_at, :naive_datetime

      timestamps()
    end

    create unique_index(:whatsapp_sessions, [:phone_number])
    create index(:whatsapp_sessions, [:status])
  end
end
