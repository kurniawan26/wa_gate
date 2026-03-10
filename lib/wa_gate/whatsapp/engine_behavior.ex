defmodule WaGate.WhatsApp.EngineBehaviour do
  @callback send_message(session :: map(), to :: String.t(), text :: String.t()) ::
              {:ok, map()} | {:error, any()}

  @callback update_presence(session :: map(), to :: String.t(), presence :: atom()) ::
              :ok | {:error, any()}

  @callback get_status(session :: map()) :: {:ok, String.t()} | {:error, any()}
end
