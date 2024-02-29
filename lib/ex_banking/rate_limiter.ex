defmodule ExBanking.RateLimiter do
  @moduledoc """
  Api call rate limiting logic
  """
  @rate_limit 10

  @spec new() :: __MODULE__
  def new do
    :ets.new(__MODULE__, [
      :named_table,
      :public,
      write_concurrency: true,
      read_concurrency: true,
      decentralized_counters: true
    ])
  end

  @spec increase(String.t()) :: {:ok, integer()} | {:error, :too_many_requests_to_user}
  def increase(user) do
    counter = :ets.update_counter(__MODULE__, user, {2, 1}, {user, 0})

    if counter > @rate_limit do
      decrease(user)
      {:error, :too_many_requests_to_user}
    else
      {:ok, counter}
    end
  end

  @spec decrease(String.t()) :: :ok
  def decrease(user) do
    :ets.update_counter(__MODULE__, user, {2, -1})
    :ok
  end
end
