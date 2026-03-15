defmodule WaGate.Messaging.InboundMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inbound_messages" do
    field :external_id, :string
    field :sender_number, :string
    field :sender_name, :string
    field :body, :string
    field :message_type, :string
    field :raw_payload, :map

    belongs_to :whatsapp_session, WaGate.Accounts.Session

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:external_id, :sender_number, :sender_name, :body, :message_type, :raw_payload, :whatsapp_session_id])
    |> validate_required([:external_id, :sender_number, :message_type, :raw_payload])
    |> unique_constraint(:external_id)
  end
end
