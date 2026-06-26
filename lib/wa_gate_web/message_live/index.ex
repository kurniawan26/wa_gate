defmodule WaGateWeb.MessageLive.Index do
  use WaGateWeb, :live_view
  alias WaGate.Messaging

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WaGate.PubSub, "messages:feed")
    end

    socket =
      socket
      |> assign(
        contacts: Messaging.list_contacts(),
        show_compose: false,
        compose_mode: :single,
        compose_to: "",
        compose_text: "",
        bulk_csv: "",
        bulk_template: "",
        bulk_preview: []
      )
      |> allow_upload(:csv_file, accept: ~w(.csv text/csv), max_entries: 1, auto_upload: true)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_compose", %{"mode" => mode}, socket) do
    {:noreply,
     assign(socket,
       show_compose: true,
       compose_mode: String.to_existing_atom(mode),
       compose_to: "",
       compose_text: "",
       bulk_csv: "",
       bulk_template: "",
       bulk_preview: []
     )}
  end

  def handle_event("close_compose", _params, socket) do
    {:noreply, assign(socket, show_compose: false)}
  end

  def handle_event("update_compose_fields", params, socket) do
    {:noreply,
     assign(socket,
       compose_to: Map.get(params, "to", socket.assigns.compose_to),
       compose_text: Map.get(params, "text", socket.assigns.compose_text)
     )}
  end

  def handle_event("update_bulk_fields", params, socket) do
    template = Map.get(params, "template", socket.assigns.bulk_template)
    socket = socket |> maybe_consume_csv() |> assign(bulk_template: template)
    preview = build_preview(socket.assigns.bulk_csv, socket.assigns.bulk_template)
    {:noreply, assign(socket, bulk_preview: preview)}
  end

  def handle_event("send_compose", _params, socket) do
    case socket.assigns.compose_mode do
      :single ->
        text = String.trim(socket.assigns.compose_text)
        to = String.trim(socket.assigns.compose_to)
        if text != "" and to != "", do: Messaging.enqueue_message(to, text)

      :bulk ->
        Enum.each(socket.assigns.bulk_preview, fn %{number: number, message: message} ->
          Messaging.enqueue_message(number, message)
        end)
    end

    {:noreply, assign(socket, show_compose: false)}
  end

  @impl true
  def handle_info({:new_inbound, _message}, socket) do
    {:noreply, assign(socket, contacts: Messaging.list_contacts())}
  end

  def handle_info({:message_sent, _message}, socket) do
    {:noreply, assign(socket, contacts: Messaging.list_contacts())}
  end

  defp maybe_consume_csv(socket) do
    case socket.assigns.uploads.csv_file.entries do
      [%{done?: true}] ->
        [content] =
          consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
            {:ok, File.read!(path)}
          end)

        preview = build_preview(content, socket.assigns.bulk_template)
        assign(socket, bulk_csv: content, bulk_preview: preview)

      _ ->
        socket
    end
  end

  defp build_preview(csv, template) do
    if String.trim(csv) == "" or String.trim(template) == "" do
      []
    else
      rows = parse_csv(csv)

      rows
      |> Enum.map(fn row ->
        %{
          number: Map.get(row, "number", ""),
          name: Map.get(row, "name", ""),
          message: interpolate(template, row)
        }
      end)
      |> Enum.reject(&(&1.number == ""))
    end
  end

  defp parse_csv(csv) do
    lines =
      csv
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [] -> []
      [_header_only] -> []
      [header_line | data_lines] ->
        headers = header_line |> String.split(",") |> Enum.map(&String.trim/1)

        Enum.map(data_lines, fn line ->
          values = line |> String.split(",") |> Enum.map(&String.trim/1)
          headers |> Enum.zip(values) |> Map.new()
        end)
    end
  end

  defp interpolate(template, row) do
    Enum.reduce(row, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", value)
    end)
  end

  defp format_time(nil), do: ""

  defp format_time(dt) do
    dt
    |> NaiveDateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end
end
