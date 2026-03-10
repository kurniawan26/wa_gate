defmodule WaGate.Repo do
  use Ecto.Repo,
    otp_app: :wa_gate,
    adapter: Ecto.Adapters.Postgres
end
