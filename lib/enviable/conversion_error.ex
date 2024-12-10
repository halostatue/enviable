defmodule Enviable.ConversionError do
  @moduledoc """
  An exception raised when a provided environment variable cannot be converted to the
  requested type.
  """

  defexception [:env, :type]

  @impl true
  def message(%{env: env, type: type}) do
    "could not convert environment variable #{inspect(env)} to type #{type}"
  end
end
