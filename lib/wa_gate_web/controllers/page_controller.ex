defmodule WaGateWeb.PageController do
  use WaGateWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/sessions")
  end
end
