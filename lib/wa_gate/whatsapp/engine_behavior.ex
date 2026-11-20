defmodule WaGate.WhatsApp.EngineBehaviour do
  @type send_error ::
          :engine_unauthorized
          | :session_not_found
          | :session_not_ready
          | {:not_delivered, term()}
          | {:delivery_unknown, term()}
          | {:http_status, integer()}

  @callback send_message(session :: map(), to :: String.t(), text :: String.t()) ::
              {:ok, map()} | {:error, send_error()}

  @callback update_presence(session :: map(), to :: String.t(), presence :: atom()) ::
              :ok | {:error, any()}

  @callback get_status(session :: map()) :: {:ok, String.t()} | {:error, any()}
end
