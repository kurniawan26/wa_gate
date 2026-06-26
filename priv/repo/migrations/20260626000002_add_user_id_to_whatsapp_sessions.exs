defmodule WaGate.Repo.Migrations.AddUserIdToWhatsappSessions do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_sessions) do
      add_if_not_exists :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create_if_not_exists index(:whatsapp_sessions, [:user_id])
  end
end
