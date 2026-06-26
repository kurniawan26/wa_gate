defmodule WaGate.Accounts.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "whatsapp_sessions" do
    field :phone_number, :string
    field :name, :string
    field :status, :string, default: "initial"
    field :auth_data, :map, default: %{}
    field :max_daily_messages, :integer, default: 100
    field :messages_sent_today, :integer, default: 0
    field :last_used_at, :naive_datetime

    belongs_to :user, WaGate.Auth.User
    has_many :outbound_messages, WaGate.Messaging.Message, foreign_key: :whatsapp_session_id

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :phone_number,
      :name,
      :status,
      :auth_data,
      :max_daily_messages,
      :messages_sent_today,
      :last_used_at,
      :user_id
    ])
    |> validate_required([:phone_number, :status])
    |> unique_constraint(:phone_number)
  end
end
