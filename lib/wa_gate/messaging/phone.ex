defmodule WaGate.Messaging.Phone do
  @moduledoc """
  Normalisasi nomor tujuan WhatsApp ke format internasional tanpa simbol
  (contoh: `"0812-3456 7890"` → `"6281234567890"`).

  ID yang sudah berupa JID (mengandung `@`, mis. `"1203...@g.us"` atau
  `"xxx@lid"`) diteruskan apa adanya.
  """

  @min_digits 8
  @max_digits 15

  @spec normalize(term()) :: {:ok, String.t()} | {:error, String.t()}
  def normalize(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" ->
        {:error, "nomor tujuan wajib diisi"}

      String.contains?(value, "@") ->
        {:ok, value}

      not Regex.match?(~r/^\+?[\d\s\-\.\(\)]+$/, value) ->
        {:error, "nomor tujuan hanya boleh berisi angka"}

      true ->
        value
        |> String.replace(~r/\D/, "")
        |> apply_country_code()
        |> validate_length()
    end
  end

  def normalize(value) when is_integer(value), do: normalize(Integer.to_string(value))
  def normalize(_), do: {:error, "nomor tujuan wajib diisi"}

  defp apply_country_code("0" <> rest), do: default_country_code() <> rest
  defp apply_country_code(digits), do: digits

  defp validate_length(digits) do
    if String.length(digits) in @min_digits..@max_digits do
      {:ok, digits}
    else
      {:error, "panjang nomor tujuan tidak valid"}
    end
  end

  defp default_country_code, do: Application.get_env(:wa_gate, :default_country_code, "62")
end
