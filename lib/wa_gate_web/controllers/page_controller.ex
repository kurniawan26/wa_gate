defmodule WaGateWeb.PageController do
  use WaGateWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
