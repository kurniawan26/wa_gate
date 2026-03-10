defmodule WaGate.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outbound_messages" do
    field :recipient_number, :string
    field :payload, :string
    field :status, :string, default: "pending"
    field :error_reason, :string
    field :retry_count, :integer, default: 0

    belongs_to :whatsapp_session, WaGate.Accounts.Session

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :recipient_number,
      :payload,
      :status,
      :whatsapp_session_id,
      :error_reason,
      :retry_count
    ])
    |> validate_required([:recipient_number, :payload, :status])
  end
end
