defmodule ExBanking.Wallet do
  @moduledoc """
  Wallet (balance) context
  """

  use GenServer

  alias ExBanking.Money
  # client
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, [], name: via_tuple(name))
  end

  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
  def deposit(user, amount, currency) do
    GenServer.call(via_tuple(user), {:deposit, {amount, currency}})
  end

  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()} | {:error, :not_enough_money}
  def withdraw(user, amount, currency) do
    GenServer.call(via_tuple(user), {:withdraw, {amount, currency}})
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) :: {:ok, balance :: number()}
  def get_balance(user, currency) do
    GenServer.call(via_tuple(user), {:get_balance, currency})
  end

  # server
  def init(_opts) do
    {:ok, %{}}
  end

  def handle_call({:deposit, {amount, currency}}, _from, state) do
    amount_in_currency = Map.get(state, currency, 0)
    updated_balance = Money.format(amount_in_currency + Money.format(amount))
    new_state = Map.put(state, currency, updated_balance)
    {:reply, {:ok, updated_balance}, new_state}
  end

  def handle_call({:withdraw, {amount, currency}}, _from, state) do
    amount = Money.format(amount)

    case Map.get(state, currency, 0) do
      balance when balance > 0 and balance >= amount ->
        updated_balance = Money.format(balance - amount)
        new_state = Map.put(state, currency, updated_balance)
        {:reply, {:ok, updated_balance}, new_state}

      _ ->
        {:reply, {:error, :not_enough_money}, state}
    end
  end

  def handle_call({:get_balance, currency}, _from, state) do
    {:reply, {:ok, Map.get(state, currency, 0)}, state}
  end

  defp via_tuple(name) do
    {:via, Registry, {ExBanking.AccountsRegistry, name}}
  end
end
