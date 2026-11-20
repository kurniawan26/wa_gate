defmodule WaGate.Release do
  @app :wa_gate

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Menyinkronkan konfigurasi webhook (termasuk kunci HMAC dari WEBHOOK_SECRET)
  ke semua sesi yang sudah terdaftar di WAHA. Jalankan setelah mengganti
  WEBHOOK_SECRET atau WEBHOOK_URL:

      bin/wa_gate eval "WaGate.Release.sync_webhooks()"
      # atau di dev: mix run -e "WaGate.Release.sync_webhooks()"
  """
  def sync_webhooks do
    load_app()
    {:ok, _} = Application.ensure_all_started(:req)

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          adapter = Application.fetch_env!(@app, :whatsapp_engine)

          for session <- repo.all(WaGate.Accounts.Session) do
            result = adapter.sync_webhook_config(session.phone_number)
            IO.puts("#{session.phone_number}: #{inspect(result)}")
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
