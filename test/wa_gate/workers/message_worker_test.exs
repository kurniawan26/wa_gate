defmodule WaGate.Workers.MessageWorkerTest do
  use WaGate.DataCase, async: true
  use Oban.Testing, repo: WaGate.Repo

  import WaGate.MessagingFixtures

  alias WaGate.{Messaging, FakeWhatsAppEngine}
  alias WaGate.Messaging.Dispatcher
  alias WaGate.Accounts.Session
  alias WaGate.Workers.MessageWorker

  setup do
    user = user_fixture()
    session = session_fixture(user)
    {:ok, msg} = Messaging.enqueue_message("6281234567890", "halo", user.id)
    %{user: user, session: session, msg: msg}
  end

  defp run(msg, opts \\ []) do
    perform_job(MessageWorker, %{"message_id" => msg.id, "user_id" => msg.user_id}, opts)
  end

  test "mengirim teks hasil dekripsi dan menandai sent", %{msg: msg, session: session} do
    assert :ok = run(msg)
    assert_received {:fake_engine, :send_message, [_, "6281234567890", "halo"]}

    msg = Repo.reload!(msg)
    assert msg.status == "sent"
    assert msg.whatsapp_session_id == session.id
    assert Repo.reload!(session).messages_sent_today == 1
  end

  test "job duplikat tidak mengirim ulang pesan yang sudah sent", %{msg: msg} do
    assert :ok = run(msg)
    assert :ok = run(msg)
    assert_received {:fake_engine, :send_message, _}
    refute_received {:fake_engine, :send_message, _}
  end

  test "error sementara di-retry lalu failed pada attempt terakhir", %{msg: msg, session: session} do
    FakeWhatsAppEngine.stub(:send_message, {:error, {:http_status, 500}})

    assert {:error, _} = run(msg, attempt: 1)
    assert %{status: "pending", retry_count: 1} = Repo.reload!(msg)
    assert Repo.reload!(session).messages_sent_today == 0

    assert {:cancel, _} = run(msg, attempt: 3)
    assert %{status: "failed", error_reason: reason} = Repo.reload!(msg)
    assert reason =~ "500"
  end

  test "status pengiriman tidak pasti tidak di-retry", %{msg: msg} do
    FakeWhatsAppEngine.stub(:send_message, {:error, {:delivery_unknown, :timeout}})

    assert {:cancel, _} = run(msg, attempt: 1)
    assert %{status: "failed", error_reason: reason} = Repo.reload!(msg)
    assert reason =~ "tidak pasti"
  end

  test "API key engine salah tidak memutus sesi", %{msg: msg, session: session} do
    FakeWhatsAppEngine.stub(:send_message, {:error, :engine_unauthorized})

    assert {:error, _} = run(msg, attempt: 1)
    assert Repo.reload!(session).status == "connected"
  end

  test "422 hanya memutus sesi bila engine mengonfirmasi tidak WORKING", %{
    msg: msg,
    session: session
  } do
    FakeWhatsAppEngine.stub(:send_message, {:error, :session_not_ready})

    FakeWhatsAppEngine.stub(:get_status, {:ok, "open"})
    assert {:error, _} = run(msg, attempt: 1)
    assert Repo.reload!(session).status == "connected"

    FakeWhatsAppEngine.stub(:get_status, {:ok, "scan_qr_code"})
    assert {:error, _} = run(msg, attempt: 2)
    assert Repo.reload!(session).status == "disconnected"
  end

  test "tanpa sesi tersedia, pesan failed setelah attempt habis", %{msg: msg, session: session} do
    Repo.update!(Session.changeset(session, %{status: "disconnected"}))

    assert {:error, _} = run(msg, attempt: 1)
    assert {:cancel, _} = run(msg, attempt: 3)
    assert %{status: "failed"} = Repo.reload!(msg)
    refute_received {:fake_engine, :send_message, _}
  end

  describe "Dispatcher" do
    test "reservasi kuota atomik tidak melewati limit", %{session: session} do
      Repo.update!(Session.changeset(session, %{max_daily_messages: 2}))

      assert {:ok, _} = Dispatcher.reserve_session(session.id)
      assert {:ok, _} = Dispatcher.reserve_session(session.id)
      assert {:error, :daily_limit_reached} = Dispatcher.reserve_session(session.id)
      assert Repo.reload!(session).messages_sent_today == 2
    end

    test "sesi yang belum pernah dipakai didahulukan", %{user: user, session: used} do
      Repo.update!(Session.changeset(used, %{last_used_at: ~N[2026-01-01 00:00:00]}))
      fresh = session_fixture(user)

      assert {:ok, %Session{id: id}} = Dispatcher.reserve_available_session(user.id)
      assert id == fresh.id
    end
  end
end
