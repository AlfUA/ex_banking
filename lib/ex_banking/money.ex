defmodule ExBanking.Money do
  @moduledoc false

  @spec format(amount :: number()) :: number()
  def format(amount) when is_float(amount), do: Float.round(amount, 2)

  def format(amount) when is_integer(amount), do: amount / 1
end
