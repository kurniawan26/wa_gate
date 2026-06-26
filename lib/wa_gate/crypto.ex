defmodule WaGate.Crypto do
  @aad ""

  def app_key do
    case Application.get_env(:wa_gate, :encryption_key) do
      nil -> raise "ENCRYPTION_KEY tidak dikonfigurasi"
      key -> Base.decode64!(key)
    end
  end

  def encrypt(plaintext, key) when is_binary(plaintext) and is_binary(key) do
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)
    Base.encode64(iv <> tag <> ciphertext)
  end

  def decrypt(encoded, key) when is_binary(encoded) and is_binary(key) do
    raw = Base.decode64!(encoded)
    <<iv::binary-12, tag::binary-16, ciphertext::binary>> = raw
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      result when is_binary(result) -> result
      :error -> nil
    end
  rescue
    _ -> nil
  end

  def derive_user_key(password, salt) when is_binary(password) and is_binary(salt) do
    :crypto.pbkdf2_hmac(:sha256, password, salt, 200_000, 32)
  end
end
