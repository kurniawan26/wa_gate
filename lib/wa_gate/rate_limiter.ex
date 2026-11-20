defmodule WaGate.RateLimiter do
  @moduledoc """
  Rate limiter fixed-window sederhana berbasis ETS (per node).

  Dipakai untuk membatasi percobaan login/registrasi yang gagal:

      case RateLimiter.check({:login_ip, ip}, 20, :timer.minutes(15)) do
        :ok -> ...
        {:error, retry_after_seconds} -> ...
      end

  `check/3` hanya membaca, `record/2` menambah hitungan, `reset/1` menghapus.
  """
  use GenServer

  @table __MODULE__
  @cleanup_interval :timer.minutes(1)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "`:ok` bila `key` belum mencapai `limit` dalam window saat ini."
  def check(key, limit, window_ms) do
    now = now_ms()

    case :ets.lookup(@table, key) do
      [{^key, count, started_at}] when now - started_at < window_ms and count >= limit ->
        {:error, max(div(window_ms - (now - started_at) + 999, 1000), 1)}

      _ ->
        :ok
    end
  end

  @doc "Mencatat satu percobaan untuk `key`."
  def record(key, window_ms) do
    now = now_ms()

    case :ets.lookup(@table, key) do
      [{^key, _count, started_at}] when now - started_at < window_ms ->
        :ets.update_counter(@table, key, {2, 1})

      _ ->
        :ets.insert(@table, {key, 1, now})
    end

    :ok
  end

  def reset(key) do
    :ets.delete(@table, key)
    :ok
  end

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    max_window = Keyword.get(opts, :max_window_ms, :timer.hours(1))
    schedule_cleanup()
    {:ok, %{max_window: max_window}}
  end

  @impl true
  def handle_info(:cleanup, %{max_window: max_window} = state) do
    cutoff = now_ms() - max_window
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, @cleanup_interval)
  defp now_ms, do: System.monotonic_time(:millisecond)
end
