defmodule WaGate.Messaging.PhoneTest do
  use ExUnit.Case, async: true

  alias WaGate.Messaging.Phone

  test "mengubah awalan 0 menjadi kode negara" do
    assert Phone.normalize("081234567890") == {:ok, "6281234567890"}
  end

  test "membuang +, spasi, strip, dan kurung" do
    assert Phone.normalize("+62 812-3456 (7890)") == {:ok, "6281234567890"}
  end

  test "menerima angka integer" do
    assert Phone.normalize(6_281_234_567_890) == {:ok, "6281234567890"}
  end

  test "JID diteruskan apa adanya" do
    assert Phone.normalize("120363000000000000@g.us") == {:ok, "120363000000000000@g.us"}
  end

  test "menolak nomor kosong, berisi huruf, atau panjang tidak valid" do
    assert {:error, _} = Phone.normalize("")
    assert {:error, _} = Phone.normalize(nil)
    assert {:error, _} = Phone.normalize("0812abc")
    assert {:error, _} = Phone.normalize("0812")
    assert {:error, _} = Phone.normalize("1234567890123456")
  end
end
