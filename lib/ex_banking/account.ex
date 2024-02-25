defmodule ExBanking.Account do
  @moduledoc """
  Account context
  """

  @spec create(String.t()) :: :ok | {:error, :user_already_exists}
  def create(user) do
    case DynamicSupervisor.start_child(
           ExBanking.UsersDynamicSupervisor,
           {ExBanking.Wallet, name: user}
         ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :user_already_exists}
    end
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(user) do
    case Registry.lookup(ExBanking.AccountsRegistry, user) do
      [{_pid, _}] -> true
      [] -> false
    end
  end
end
