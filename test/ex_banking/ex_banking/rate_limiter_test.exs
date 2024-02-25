defmodule ExBanking.RateLimiterTest do
  use ExUnit.Case

  alias ExBanking.{AccountsRegistry, RateLimiter}

  @user1 "User 1"

  setup do
    :ok = ExBanking.create_user(@user1)

    on_exit(fn ->
      [{pid, _}] = Registry.lookup(AccountsRegistry, @user1)
      :ok = DynamicSupervisor.terminate_child(ExBanking.UsersDynamicSupervisor, pid)
    end)
  end

  test "max counter's value depends on the limit" do
    #    max allowed number exceeded
    for _n <- 1..15, do: RateLimiter.increase(@user1)
    assert 10 = :ets.lookup_element(RateLimiter, @user1, 2)
  end

  test "correctly sets the counter's value when queue is fully drained" do
    #    max allowed number exceeded
    for _n <- 1..15, do: RateLimiter.increase(@user1)
    assert 10 = :ets.lookup_element(RateLimiter, @user1, 2)
    #    queue processed, counter should have initial value now
    for _n <- 1..10, do: RateLimiter.decrease(@user1)
    assert 0 = :ets.lookup_element(RateLimiter, @user1, 2)
  end
end
