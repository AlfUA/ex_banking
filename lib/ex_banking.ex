defmodule ExBanking do
  @moduledoc """
  User facing API that creates user and manipulates with the account state
  """
  alias ExBanking.{Account, RateLimiter, Wallet}

  defguardp is_user(user) when is_binary(user) and user != ""
  defguardp is_amount(amount) when (is_integer(amount) or is_float(amount)) and amount >= 0
  defguardp is_currency(currency) when is_binary(currency) and currency != ""

  @doc """
  Function creates new user in the system
  New user has zero balance of any currency
  """
  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_user(user), do: Account.create(user)

  def create_user(_user), do: {:error, :wrong_arguments}

  @doc """
  Increases user’s balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_user(user) and is_amount(amount) and is_currency(currency) do
    with {_, true} <- {:exists?, Account.exists?(user)},
         {_, {:ok, _counter}} <- {:rate_limit_check, RateLimiter.increase(user)} do
      {:ok, new_balance} = Wallet.deposit(user, amount, currency)
      RateLimiter.decrease(user)
      {:ok, new_balance}
    else
      {:exists?, false} ->
        {:error, :user_does_not_exist}

      {:rate_limit_check, error} ->
        error
    end
  end

  def deposit(_user, _amount, _currency) do
    {:error, :wrong_arguments}
  end

  @doc """
  Decreases user’s balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
      when is_user(user) and is_amount(amount) and is_currency(currency) do
    with {_, true} <- {:exists?, Account.exists?(user)},
         {_, {:ok, _counter}} <- {:rate_limit_check, RateLimiter.increase(user)},
         {_, {:ok, new_balance}} <- {:sufficial_funds?, Wallet.withdraw(user, amount, currency)} do
      RateLimiter.decrease(user)
      {:ok, new_balance}
    else
      {:exists?, false} ->
        {:error, :user_does_not_exist}

      {:sufficial_funds?, error} ->
        RateLimiter.decrease(user)
        error

      {:rate_limit_check, error} ->
        error
    end
  end

  def withdraw(_user, _amount, _currency) do
    {:error, :wrong_arguments}
  end

  @doc """
  Returns balance of the user in given format
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) when is_user(user) and is_currency(currency) do
    with {_, true} <- {:exists?, Account.exists?(user)},
         {_, {:ok, _counter}} <- {:rate_limit_check, RateLimiter.increase(user)} do
      {:ok, balance} = Wallet.get_balance(user, currency)
      RateLimiter.decrease(user)
      {:ok, balance}
    else
      {:exists?, false} ->
        {:error, :user_does_not_exist}

      {:rate_limit_check, error} ->
        error
    end
  end

  def get_balance(_user, _currency) do
    {:error, :wrong_arguments}
  end

  @doc """
  Returns balance of the user in given format
  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number(),
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number(), to_user_balance :: number()}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
      when is_user(from_user) and is_user(to_user) and is_amount(amount) and is_currency(currency) do
    with {_, true} <- {:from_exists?, Account.exists?(from_user)},
         {_, true} <- {:to_exists?, Account.exists?(to_user)},
         {_, {:ok, _counter}} <- {:rate_limit_check_from, RateLimiter.increase(from_user)},
         {_, {:ok, _counter}} <- {:rate_limit_check_to, RateLimiter.increase(to_user)},
         {_, {:ok, new_balance_from}} <-
           {:sufficial_funds?, Wallet.withdraw(from_user, amount, currency)} do
      {:ok, new_balance_to} = Wallet.deposit(to_user, amount, currency)
      RateLimiter.decrease(from_user)
      RateLimiter.decrease(to_user)
      {:ok, new_balance_from, new_balance_to}
    else
      {:from_exists?, false} ->
        {:error, :sender_does_not_exist}

      {:to_exists?, false} ->
        {:error, :receiver_does_not_exist}

      {:rate_limit_check_from, _error} ->
        {:error, :too_many_requests_to_sender}

      {:rate_limit_check_to, _error} ->
        {:error, :too_many_requests_to_receiver}

      {:sufficial_funds?, error} ->
        RateLimiter.decrease(from_user)
        RateLimiter.decrease(to_user)
        error
    end
  end

  def send(_from_user, _to_user, _amount, _currency) do
    {:error, :wrong_arguments}
  end
end
