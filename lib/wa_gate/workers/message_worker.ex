defmodule WaGate.Workers.MessageWorker do
  use Oban.Worker, queue: :messaging, max_attempts: 3

  alias WaGate.Repo
  alias WaGate.Messaging.{Message, Dispatcher}
  alias WaGate.Accounts

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => message_id, "plaintext" => plaintext, "user_id" => user_id} = args}) do
    message = Repo.get!(Message, message_id)
    message_with_plaintext = %{message | payload: plaintext}
    session_id = Map.get(args, "session_id")

    case resolve_session(session_id, user_id) do
      {:ok, session} -> send_via_adapter(session, message_with_plaintext)
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_session(nil, user_id) do
    case Dispatcher.get_available_session(user_id) do
      nil -> {:error, "No active WhatsApp sessions available for this user"}
      session -> {:ok, session}
    end
  end

  defp resolve_session(session_id, _user_id) do
    session = Accounts.get_session!(session_id)

    cond do
      session.status != "connected" ->
        {:error, "Session #{session_id} is not connected"}

      session.messages_sent_today >= session.max_daily_messages ->
        {:error, "Session #{session_id} has reached daily limit"}

      true ->
        {:ok, session}
    end
  end

  defp send_via_adapter(session, message) do
    adapter = Application.get_env(:wa_gate, :whatsapp_engine)

    adapter.update_presence(session, message.recipient_number, :composing)
    base_delay = message.payload |> String.length() |> Kernel.*(50) |> max(1000) |> min(5000)
    jitter = :rand.uniform(1000) - 500
    Process.sleep(base_delay + jitter)

    case adapter.send_message(session, message.recipient_number, message.payload) do
      {:ok, _res} ->
        {:ok, updated} = update_message_status(message, "sent", session.id)
        update_session_usage(session)
        Phoenix.PubSub.broadcast(WaGate.PubSub, "messages:feed", {:message_sent, updated})
        :ok

      {:error, :unauthorized} ->
        mark_session_disconnected(session)
        {:cancel, "Session disconnected (unauthorized)"}

      {:error, :session_failed} ->
        mark_session_disconnected(session)
        {:cancel, "Session crashed or logged out on Waha engine"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_message_status(msg, status, session_id) do
    msg |> Message.changeset(%{status: status, whatsapp_session_id: session_id}) |> Repo.update()
  end

  defp update_session_usage(session) do
    new_usage = session.messages_sent_today + 1

    session
    |> Accounts.Session.changeset(%{
      messages_sent_today: new_usage,
      last_used_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  defp mark_session_disconnected(session) do
    session |> Accounts.Session.changeset(%{status: "disconnected"}) |> Repo.update()
  end
end
