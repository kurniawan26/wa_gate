defmodule WaGateWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WaGateWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 h-14 border-b border-gray-200 bg-white/90 backdrop-blur">
      <nav class="mx-auto flex h-full max-w-5xl items-center gap-1 px-4 text-sm">
        <.link navigate={~p"/sessions"} class="mr-4 font-semibold text-gray-900">WaGate</.link>
        <.nav_link href={~p"/sessions"}>Sessions</.nav_link>
        <.nav_link href={~p"/messages"}>Pesan</.nav_link>
        <.nav_link href={~p"/settings"}>Pengaturan</.nav_link>
        <%= if @current_user do %>
          <span class="ml-auto hidden text-gray-500 sm:inline">{@current_user.name}</span>
          <.link
            method="delete"
            href={~p"/logout"}
            class="ml-3 rounded-lg px-3 py-1.5 text-gray-600 transition hover:bg-gray-100 hover:text-gray-900"
          >
            Logout
          </.link>
        <% end %>
      </nav>
    </header>

    <main>
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="rounded-lg px-3 py-1.5 text-gray-600 transition hover:bg-gray-100 hover:text-gray-900"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
