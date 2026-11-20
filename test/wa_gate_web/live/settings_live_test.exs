defmodule WaGateWeb.SettingsLiveTest do
  use WaGateWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WaGate.MessagingFixtures

  test "membuat API key menampilkan key sekali", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = conn |> log_in(user) |> live(~p"/settings")

    refute has_element?(view, "#new-api-key")
    view |> element("#generate-api-key") |> render_click()
    assert has_element?(view, "#new-api-key-value")

    key =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#new-api-key-value")
      |> LazyHTML.attribute("value")
      |> List.first()

    assert WaGate.Auth.get_user_by_api_key(key).id == user.id

    view |> element("#dismiss-api-key") |> render_click()
    refute has_element?(view, "#new-api-key")
    assert has_element?(view, "#revoke-api-key")
  end

  test "halaman settings butuh login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/settings")
  end
end
