defmodule Enviable.Errors do
  # Shared formatting for Enviable exception messages.

  @moduledoc false

  @doc """
  Describes the value being converted.

  - `source: :env`: `environment variable "PORT"`, `environment variable "PORT[1]"`
  - `source: :map`: `environment map variable "PORT"`
  - `source: :default`: `environment variable "PORT" default`, `... "PORT" default[1]`
  """
  @spec label(String.t(), atom(), nil | non_neg_integer()) :: String.t()
  def label(name, :default, index), do: "environment variable #{inspect(name)} default#{format_index(index)}"
  def label(name, :map, index), do: "environment map variable #{inspect(name <> format_index(index))}"
  def label(name, _env, index), do: "environment variable #{inspect(name <> format_index(index))}"

  @doc "Formats a conversion type for messages."
  @spec format_type(term()) :: String.t()
  def format_type(type) when is_atom(type), do: Atom.to_string(type)
  def format_type(type), do: inspect(type)

  defp format_index(nil), do: ""
  defp format_index(index), do: "[#{index}]"
end

defmodule Enviable.ConversionError do
  @moduledoc """
  An exception raised when a value cannot be converted to the requested type.

  The message names the variable (and the list element or default, if applicable) and
  the type, but never the value.

  ### Fields

  - `:env`: the variable name
  - `:source`: `:env`, `:map`, or `:default` (the value came from a conversion default)
  - `:index`: the list element index (`1` is the second element of a list conversion), or
    `nil`
  - `:type`: the conversion type that failed
  """

  defexception [:env, :type, :index, source: :env]

  @type t :: %__MODULE__{
          env: String.t(),
          type: term(),
          source: :env | :map | :default,
          index: nil | non_neg_integer()
        }

  @impl Exception
  def message(%{env: env, type: type, source: source, index: index}) do
    "could not convert #{Enviable.Errors.label(env, source, index)} to type #{Enviable.Errors.format_type(type)}"
  end
end

defmodule Enviable.OptionError do
  @moduledoc """
  An exception raised when conversion options are invalid: an unknown option, an option
  value of the wrong type, conflicting options, or a `:default` that cannot be used for
  the requested type.

  The message never includes `:default` values, which may be secrets.

  ### Fields

  - `:env`: the variable name
  - `:source`: `:env`, `:map`, or `:default` (a list default element was invalid)
  - `:index`: the list element index of an invalid list default element, or `nil`
  - `:type`: the requested conversion type
  - `:key`: the invalid option, a list of unknown options, or `nil`
  - `:reason`: a description of the problem
  """

  defexception [:env, :type, :key, :reason, :index, source: :env]

  @type t :: %__MODULE__{
          env: String.t(),
          type: term(),
          key: nil | atom() | [atom()],
          reason: String.t(),
          source: :env | :map | :default,
          index: nil | non_neg_integer()
        }

  @impl Exception
  def message(%{env: env, type: type, source: source, index: index, reason: reason}) do
    "could not convert #{Enviable.Errors.label(env, source, index)} to type #{Enviable.Errors.format_type(type)}: #{reason}"
  end
end

defmodule Enviable.UnsupportedConversionError do
  @moduledoc """
  An exception raised when a conversion type is not supported, before any conversion is
  attempted.

  Supported conversions are primitive types, encoded types, and `{encoding, primitive}`
  tuples. Encoded types may not be nested (`{:base64, :list}` is not supported), and some
  primitives may not be list elements (`{:list, :json}`).
  """

  defexception [:type, :reason]

  @type t :: %__MODULE__{type: term(), reason: String.t()}

  @impl Exception
  def message(%{type: type, reason: reason}), do: "unsupported conversion #{inspect(type)}: #{reason}"
end

defmodule Enviable.EnvMapError do
  @moduledoc """
  An exception raised when a variable cannot be found in an environment map.
  """

  defexception [:env]

  @impl Exception
  def message(%{env: env}) do
    "could not fetch environment map variable #{inspect(env)} because it is not set"
  end
end
