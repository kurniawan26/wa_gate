defmodule WaGate.MessagingTest do
  use WaGate.DataCase, async: true
  use Oban.Testing, repo: WaGate.Repo

  import WaGate.MessagingFixtures

  alias WaGate.Messaging
  alias WaGate.Messaging.Message
  alias WaGate.Workers.MessageWorker

  setup do
    user = user_fixture()
    %{user: user, session: session_fixture(user)}
  end

  describe "enqueue_message/4" do
    test "menyimpan pesan terenkripsi dan job tanpa plaintext", %{user: user} do
      assert {:ok, %Message{} = msg} =
               Messaging.enqueue_message("0812 3456 7890", "halo", user.id)

      assert msg.recipient_number == "6281234567890"
      assert msg.status == "pending"
      assert msg.payload != "halo"
      assert Messaging.decrypt_payload(msg) == "halo"

      assert_enqueued worker: MessageWorker, args: %{message_id: msg.id}
      [job] = all_enqueued(worker: MessageWorker)
      refute Map.has_key?(job.args, "plaintext")
      refute inspect(job.args) =~ "halo"
    end

    test "mengembalikan error (bukan crash) untuk input tidak valid", %{user: user} do
      assert {:error, %Ecto.Changeset{} = cs} = Messaging.enqueue_message("0812", "", user.id)
      assert Messaging.error_summary(cs) =~ "teks pesan wajib diisi"
      assert Messaging.error_summary(cs) =~ "nomor tujuan"
      refute_enqueued worker: MessageWorker
    end

    test "pesan pending tampil di kontak dan thread", %{user: user} do
      {:ok, _} = Messaging.enqueue_message("6281234567890", "halo", user.id)

      assert [%{number: "6281234567890", preview: "halo"}] = Messaging.list_contacts(user.id)

      assert [%{status: "pending", payload: "halo"}] =
               Messaging.list_thread("6281234567890", user.id)
    end

    test "pesan user lain tidak terlihat", %{user: user} do
      other = user_fixture()
      {:ok, _} = Messaging.enqueue_message("6281234567890", "rahasia", other.id)

      assert Messaging.list_contacts(user.id) == []
      assert Messaging.list_thread("6281234567890", user.id) == []
    end
  end
end
