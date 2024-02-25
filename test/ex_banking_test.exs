defmodule ExBankingTest do
  use ExUnit.Case

  alias ExBanking.{AccountsRegistry, RateLimiter}

  @user1 "User 1"
  @user2 "User 2"
  @user3 "User 3"
  @user4 "User 4"
  @user5 "User 5"
  @user6 "User 6"
  @sender1 "Sender 1"
  @sender2 "Sender 2"
  @receiver1 "Receiver 1"
  @receiver2 "Receiver 2"
  @random_operation_user "Random Operation User"

  describe "create_user/1" do
    test "creates user successfully" do
      assert :ok = ExBanking.create_user(@user1)
      assert :ok = clean_registry(@user1)
    end

    test "error when user name is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.create_user("")
    end

    test "error when user name is not a string" do
      assert {:error, :wrong_arguments} = ExBanking.create_user(123)
    end

    test "error when user already exists" do
      assert :ok = ExBanking.create_user(@user1)
      assert {:error, :user_already_exists} = ExBanking.create_user(@user1)
      assert :ok = clean_registry(@user1)
    end
  end

  describe "deposit/3" do
    setup do
      :ok = ExBanking.create_user(@user2)
      on_exit(fn -> clean_registry(@user2) end)
    end

    test "error user name is not string" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(123, 1, "USD")
    end

    test "error when currency is not string" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, 1, 123)
    end

    test "error when amount is not a number" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, "123.05", "USD")
    end

    test "error when user name is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.deposit("", 1, "USD")
    end

    test "error when currency is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, 1, "")
    end

    test "error when amount is negative" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, -100, "USD")
    end

    test "error when user does not exist" do
      assert {:error, :user_does_not_exist} = ExBanking.deposit("Unknown", 1, "USD")
    end

    test "creates USD currency successfully" do
      assert {:ok, 10.0} = ExBanking.deposit(@user2, 10, "USD")
    end

    test "increases balance for one currency" do
      assert {:ok, 10.0} = ExBanking.deposit(@user2, 10, "USD")
      assert {:ok, 20.0} = ExBanking.deposit(@user2, 10, "USD")
    end

    test "increases balance for multiple currencies" do
      assert {:ok, 10.01} = ExBanking.deposit(@user2, 10.0123, "USD")
      assert {:ok, 30.01} = ExBanking.deposit(@user2, 20, "USD")
      assert {:ok, 10.77} = ExBanking.deposit(@user2, 10.765, "EUR")
      assert {:ok, 40.77} = ExBanking.deposit(@user2, 30, "EUR")
    end
  end

  describe "withdraw/3" do
    setup do
      :ok = ExBanking.create_user(@user3)
      on_exit(fn -> clean_registry(@user3) end)
    end

    test "error when user name is not string" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(123, 1, "USD")
    end

    test "error when currency is not string" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, 1, 234)
    end

    test "error when amount is not a number" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, "123.05", "USD")
    end

    test "error when user name is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw("", 1, "USD")
    end

    test "error when currency is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, 1, "")
    end

    test "error when amount is negative" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, -100, "USD")
    end

    test "error when user does not exist" do
      assert {:error, :user_does_not_exist} = ExBanking.withdraw("Unknown", 1, "USD")
    end

    test "error when user doesn't have money in requested currency" do
      assert {:error, :not_enough_money} = ExBanking.withdraw(@user3, 10, "USD")
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "USD")
      assert {:error, :not_enough_money} = ExBanking.withdraw(@user3, 5, "EUR")
    end

    test "error when user doesn't have enough money" do
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "USD")
      assert {:error, :not_enough_money} = ExBanking.withdraw(@user3, 11, "USD")
      assert {:error, :not_enough_money} = ExBanking.withdraw(@user3, 10.20, "USD")
    end

    test "0 balance when all amount withdrawned" do
      assert {:ok, 10.12} = ExBanking.deposit(@user3, 10.123, "USD")
      assert {:ok, 0.0} = ExBanking.withdraw(@user3, 10.12, "USD")
    end
  end

  describe "get_balance/2" do
    setup do
      :ok = ExBanking.create_user(@user4)
      on_exit(fn -> clean_registry(@user4) end)
    end

    test "error when user name is not a string" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(123, "USD")
    end

    test "error when currency is not a string" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user1, 123)
    end

    test "error when user name is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance("", "USD")
    end

    test "error when currency is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user1, "")
    end

    test "error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.get_balance("Unknown", "USD")
    end

    test "0 balance when account wasn't deposited" do
      assert {:ok, 0} = ExBanking.get_balance(@user4, "USD")
    end

    test "0 balance when currency is not found" do
      assert {:ok, 10} == ExBanking.deposit(@user4, 10, "USD")
      assert {:ok, 0} = ExBanking.get_balance(@user4, "EUR")
    end

    test "gets balance successfully" do
      assert {:ok, 10} == ExBanking.deposit(@user4, 10, "USD")
      assert {:ok, 10} == ExBanking.deposit(@user4, 10, "EUR")

      assert {:ok, 10.0} = ExBanking.get_balance(@user4, "USD")
      assert {:ok, 10.0} = ExBanking.get_balance(@user4, "EUR")
    end
  end

  describe "send/4" do
    setup do
      :ok = ExBanking.create_user(@user5)
      :ok = ExBanking.create_user(@user6)

      on_exit(fn ->
        clean_registry(@user5)
        clean_registry(@user6)
      end)
    end

    test "error when user name is not a string" do
      assert {:error, :wrong_arguments} = ExBanking.send(123, @user6, 1, "USD")
    end

    test "error when currency is not a string" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 1, 123)
    end

    test "error when amount is not a number" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, "123.05", "USD")
    end

    test "error when user name is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.send("", "", 1, "USD")
    end

    test "error when currency is an empty string" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 1, "")
    end

    test "error when amount is negative" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, -100, "USD")
    end

    test "error when sender does not exist" do
      assert {:error, :sender_does_not_exist} = ExBanking.send("Unknown", @user6, 100, "USD")
    end

    test "error when receiver does not exist" do
      assert {:ok, 10.0} = ExBanking.deposit(@user5, 10, "USD")

      assert {:error, :receiver_does_not_exist} = ExBanking.send(@user5, "Unknown", 1, "USD")
    end

    test "error when currency is not found" do
      assert {:error, :not_enough_money} = ExBanking.send(@user5, @user6, 100, "USD")
    end

    test "error when it's not enough money" do
      assert {:ok, 0.1} = ExBanking.deposit(@user5, 0.1, "USD")
      assert {:error, :not_enough_money} = ExBanking.send(@user5, @user6, 100, "USD")
    end

    test "sends money successfully" do
      assert {:ok, 10.0} = ExBanking.deposit(@user5, 10, "USD")
      assert {:ok, 10.0} = ExBanking.deposit(@user6, 10, "USD")

      assert {:ok, 5.0, 15.0} = ExBanking.send(@user5, @user6, 5, "USD")
    end
  end

  describe "too many requests cases" do
    setup do
      :ok = ExBanking.create_user(@sender1)
      :ok = ExBanking.create_user(@sender2)
      :ok = ExBanking.create_user(@receiver1)
      :ok = ExBanking.create_user(@receiver2)
      :ok = ExBanking.create_user(@random_operation_user)

      on_exit(fn ->
        clean_registry(@sender1)
        clean_registry(@sender2)
        clean_registry(@receiver1)
        clean_registry(@receiver2)
        clean_registry(@random_operation_user)
      end)
    end

    test "error when too many requests on deposit" do
      # Emulating multiple calls to modify user balance, that will make tests more stable
      for _n <- 1..10, do: RateLimiter.increase(@random_operation_user)

      assert {:error, :too_many_requests_to_user} =
               ExBanking.deposit(@random_operation_user, 1, "USD")
    end

    test "error when too many requests on withdraw" do
      ExBanking.deposit(@random_operation_user, 100, "USD")
      # Emulating multiple calls to modify user balance, that will make tests more stable
      for _n <- 1..10, do: RateLimiter.increase(@random_operation_user)

      assert {:error, :too_many_requests_to_user} =
               ExBanking.withdraw(@random_operation_user, 1, "USD")
    end

    test "error when too many requests on balance check" do
      # Emulating multiple calls to modify user balance, that will make tests more stable
      for _n <- 1..10, do: RateLimiter.increase(@random_operation_user)

      assert {:error, :too_many_requests_to_user} =
               ExBanking.get_balance(@random_operation_user, "USD")
    end

    test "error when too many requests to sender on send operation" do
      ExBanking.deposit(@sender1, 100, "USD")
      # Emulating multiple calls to modify user balance, that will make tests more stable
      for _n <- 1..10, do: RateLimiter.increase(@sender1)

      assert {:error, :too_many_requests_to_sender} =
               ExBanking.send(@sender1, @receiver1, 1, "USD")
    end

    test "error when too many requests to receiver on send operation" do
      ExBanking.deposit(@receiver2, 100, "USD")
      ExBanking.deposit(@sender2, 100, "USD")
      # Emulating multiple calls to modify user balance, that will make tests more stable
      for _n <- 1..10, do: RateLimiter.increase(@receiver2)

      assert {:error, :too_many_requests_to_receiver} =
               ExBanking.send(@sender2, @receiver2, 1, "USD")
    end
  end

  defp clean_registry(user) do
    [{pid, _}] = Registry.lookup(AccountsRegistry, user)
    :ok = DynamicSupervisor.terminate_child(ExBanking.UsersDynamicSupervisor, pid)
  end
end
