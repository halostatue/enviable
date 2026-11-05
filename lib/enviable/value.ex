defmodule Enviable.Value do
  @moduledoc ~S"""
  Enviable.Value is an environment variable value that carries its origin and name.

  `inspect/2` omits the inner value, so a Value can be logged or inspected in an error
  without revealing its value.

  Values may be secure (retrieved from the Codex `once` functions, or always if `paranoid`
  is enabled) or plain. When a `Value.is_secure/1` is true, only `to_string(value)` and
  `"#{value}"` (interpolation) can expose the inner value.

  When values are plain, formatting that bypasses the `Inspect` protocol, such as
  `inspect(value, structs: false)`, `to_string(value)`, `"#{value}"`, or Erlang's `~p` in
  crash reports can reveal the inner value.
  """
  @moduledoc since: "3.0.0"

  @typedoc """
  A retrieved Enviable value.

  A [Value](`t:t/0`) may be `unset?/1` (its inner value is `nil`). Use `set?/1` and
  `unset?/1` to test this.

  A Value's `source` indicates its origin:

  - `:env`: read from the environment (`get_env/1` and related functions), or
    provided as a default value to `get_env/2`

  - `:map`: read from an environment map (`System.get_env/0` or the output of dotenv
    loaders), or provided as a default value to `get_env_map/2`

  - `:default`: a conversion default being converted in place of an unset value

  A Value's `index` is the element index within a list conversion (`1` is the second
  element). It is `nil` for values read from the environment or a map, and is used in
  error messages.

  The inner value is a `t:binary/0` rather than a `t:String.t/0` because decoded values
  (for example, from `{:base64, type}` conversions) may not be valid UTF-8.
  """
  @typedoc since: "3.0.0"
  @type t :: %__MODULE__{
          name: String.t(),
          source: :default | :map | :env,
          value: nil | String.t() | (-> String.t()),
          index: nil | non_neg_integer()
        }

  @typedoc """
  An environment variable map.
  """
  @typedoc since: "3.0.0"
  @type env_map :: %{optional(String.t()) => String.t() | (-> String.t())}

  @derive {Inspect, only: [:source, :name]}

  @enforce_keys [:name, :value]
  defstruct [:name, :value, :index, source: :env]

  @doc """
  Returns `true` if the Value is secure (its inner value is wrapped in a closure).

  May be used as a guard.
  """
  @doc since: "3.0.0"
  @spec is_secure(t()) :: boolean
  # coveralls-ignore-next-line - guard macro, expanded at compile time
  defguard is_secure(value) when is_function(value.value, 0)

  @doc """
  Returns `true` if the Value is secure (its inner value is wrapped in a closure).
  """
  @doc since: "3.0.0"
  @spec secure?(t()) :: boolean
  def secure?(value), do: is_secure(value)

  @doc """
  If the Value is set and not a secure value, makes it secure by wrapping its inner value
  in a closure.
  """
  @doc since: "3.0.0"
  @spec secure(t()) :: t()
  def secure(%__MODULE__{value: closure} = value) when is_function(closure, 0), do: value
  def secure(%__MODULE__{value: nil} = value), do: value

  def secure(%__MODULE__{} = value) do
    inner = value.value
    %{value | value: fn -> inner end}
  end

  @doc """
  Returns `true` if the Value is unset (its inner value is `nil`).

  May be used as a guard.
  """
  @doc since: "3.0.0"
  @spec is_unset(t()) :: boolean()
  # coveralls-ignore-next-line - guard macro, expanded at compile time
  defguard is_unset(value) when is_nil(value.value)

  @doc """
  Returns `true` if the Value is set (its inner value is not `nil`).
  """
  @doc since: "3.0.0"
  @spec set?(t()) :: boolean()
  def set?(value), do: not is_unset(value)

  @doc """
  Returns `true` if the Value is unset (its inner value is `nil`).
  """
  @doc since: "3.0.0"
  @spec unset?(t()) :: boolean()
  def unset?(value), do: is_unset(value)

  @doc false
  def __unwrap__(%__MODULE__{value: closure}) when is_function(closure, 0), do: closure.()
  def __unwrap__(%__MODULE__{value: nil}), do: nil
  def __unwrap__(%__MODULE__{value: raw}), do: raw

  defimpl String.Chars do
    def to_string(%@for{value: value}) when is_function(value, 0), do: Kernel.to_string(value.())
    def to_string(%@for{value: value}) when is_nil(value) or is_binary(value), do: Kernel.to_string(value)
  end
end
