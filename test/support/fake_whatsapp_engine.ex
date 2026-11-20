defmodule WaGate.FakeWhatsAppEngine do
  @moduledoc """
  Engine WhatsApp palsu untuk test. Respons diatur per proses test via
  `stub/2`, dan setiap panggilan dikirim ke proses test sebagai pesan
  `{:fake_engine, fun, args}`.
  """
  @behaviour WaGate.WhatsApp.EngineBehaviour

  def stub(fun, response), do: Process.put({__MODULE__, fun}, response)

  @impl true
  def send_message(session, to, text) do
    notify(:send_message, [session.id, to, text])
    Process.get({__MODULE__, :send_message}, {:ok, %{}})
  end

  @impl true
  def update_presence(_session, _to, _presence), do: :ok

  @impl true
  def get_status(session) do
    notify(:get_status, [session.id])
    Process.get({__MODULE__, :get_status}, {:ok, "open"})
  end

  def create_instance(_phone), do: {:ok, :created}
  def fetch_qr(_session), do: {:error, :qr_not_ready}
  def sync_webhook_config(_phone), do: :ok

  defp notify(fun, args), do: send(self(), {:fake_engine, fun, args})
end
