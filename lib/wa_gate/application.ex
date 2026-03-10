defmodule WaGate.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WaGateWeb.Telemetry,
      WaGate.Repo,
      {DNSCluster, query: Application.get_env(:wa_gate, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:wa_gate, Oban)},
      {Phoenix.PubSub, name: WaGate.PubSub},
      # Start a worker by calling: WaGate.Worker.start_link(arg)
      # {WaGate.Worker, arg},
      # Start to serve requests, typically the last entry
      WaGateWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WaGate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WaGateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
