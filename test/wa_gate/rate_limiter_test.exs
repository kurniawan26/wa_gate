defmodule WaGate.RateLimiterTest do
  use ExUnit.Case, async: true

  alias WaGate.RateLimiter

  setup do
    %{key: {:test, make_ref()}}
  end

  test "memblokir setelah limit tercapai dan bisa di-reset", %{key: key} do
    window = :timer.minutes(1)

    for _ <- 1..3 do
      assert :ok = RateLimiter.check(key, 3, window)
      RateLimiter.record(key, window)
    end

    assert {:error, retry_after} = RateLimiter.check(key, 3, window)
    assert retry_after in 1..60

    RateLimiter.reset(key)
    assert :ok = RateLimiter.check(key, 3, window)
  end

  test "window yang sudah lewat dihitung ulang dari nol", %{key: key} do
    RateLimiter.record(key, 0)
    RateLimiter.record(key, 0)
    assert :ok = RateLimiter.check(key, 1, 0)
  end
end
