defmodule WaGate.Messaging.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending sent failed)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outbound_messages" do
    field :recipient_number, :string
    field :payload, :string
    field :status, :string, default: "pending"
    field :error_reason, :string
    field :retry_count, :integer, default: 0

    belongs_to :whatsapp_session, WaGate.Accounts.Session
    belongs_to :user, WaGate.Auth.User

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
      :user_id,
      :error_reason,
      :retry_count
    ])
    |> validate_required([:recipient_number, :payload, :status])
    |> validate_inclusion(:status, @statuses)
    |> normalize_recipient()
  end

  defp normalize_recipient(changeset) do
    case get_change(changeset, :recipient_number) do
      nil ->
        changeset

      number ->
        case WaGate.Messaging.Phone.normalize(number) do
          {:ok, normalized} -> put_change(changeset, :recipient_number, normalized)
          {:error, msg} -> add_error(changeset, :recipient_number, msg)
        end
    end
  end
end
