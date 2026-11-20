defmodule WaGate.AuthTest do
  use WaGate.DataCase, async: true

  import WaGate.MessagingFixtures

  alias WaGate.Auth

  test "user baru belum punya API key" do
    user = user_fixture()
    assert user.api_key_hash == nil
  end

  test "API key disimpan sebagai hash dan bisa dipakai untuk lookup" do
    user = user_fixture()
    assert {:ok, "wag_" <> _ = key, updated} = Auth.generate_api_key(user)

    assert updated.api_key_hash != key
    refute updated.api_key_hash =~ key
    assert String.starts_with?(key, updated.api_key_prefix)
    assert Auth.get_user_by_api_key(key).id == user.id
  end

  test "membuat ulang key membatalkan key lama" do
    user = user_fixture()
    {:ok, old_key, user} = Auth.generate_api_key(user)
    {:ok, new_key, _} = Auth.generate_api_key(user)

    assert Auth.get_user_by_api_key(old_key) == nil
    assert Auth.get_user_by_api_key(new_key).id == user.id
  end

  test "mencabut key" do
    user = user_fixture()
    {:ok, key, user} = Auth.generate_api_key(user)
    {:ok, _} = Auth.revoke_api_key(user)

    assert Auth.get_user_by_api_key(key) == nil
  end

  test "token kosong atau bukan string tidak cocok dengan user mana pun" do
    assert Auth.get_user_by_api_key("") == nil
    assert Auth.get_user_by_api_key(nil) == nil
  end
end
