defmodule WaGateWeb.Router do
  use WaGateWeb, :router

  import WaGateWeb.UserAuth, only: [fetch_current_user: 2, require_authenticated_user: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WaGateWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug WaGateWeb.Plugs.ApiAuth
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  scope "/api", WaGateWeb do
    pipe_through :api

    post "/webhooks/whatsapp", WebhookController, :receive
  end

  scope "/api", WaGateWeb do
    pipe_through :api_authenticated

    post "/messages", Api.MessageController, :create
  end

  # Routes publik (tanpa auth)
  scope "/", WaGateWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    post "/login", AuthController, :create
    delete "/logout", AuthController, :delete
    get "/register", AuthController, :register
    post "/register", AuthController, :create_user
  end

  # Routes yang butuh login
  scope "/", WaGateWeb do
    pipe_through [:browser, :require_auth]

    get "/", PageController, :home

    live_session :authenticated,
      on_mount: [{WaGateWeb.UserAuth, :require_auth}] do
      live "/sessions", SessionLive.Index, :index
      live "/sessions/:id", SessionLive.Show, :show
      live "/messages", MessageLive.Index, :index
      live "/messages/:number", MessageLive.Thread, :show
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:wa_gate, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WaGateWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
