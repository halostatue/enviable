defmodule Enviable.ConversionCase do
  @moduledoc """
  Enviable conversion test case.
  """

  use ExUnit.CaseTemplate

  alias Enviable.Conversion
  alias Enviable.Errors
  alias Enviable.Value

  using do
    quote do
      import Enviable.ConversionCase
      import Enviable.Fixtures.PEM
    end
  end

  @doc """
  This type helper exists to provide a level of obfuscation to incoming types that prevent
  the Elixir 1.20 gradual type checker from reporting _correctly_ that some of the types
  are incompatible types.

  ```
  warning: incompatible types given to convert_as/2: convert_as("1", :bogus)
  ```

  This function returns a `dynamic()` type, preventing the gradual type checker from
  returning that type. This needs to be done because the code that will provide a runtime
  exception on invalid types and type combinations only does so when provided an invalid
  combination or invalid type.
  """
  def t(v), do: Map.get(%{v => v}, v)

  def assert_config_error(reason, value, type, options) do
    assert_raise Enviable.OptionError, config_error(type, reason), fn ->
      convert_as(value, type, options)
    end
  end

  def assert_conversion_error(value, type, options \\ []) do
    assert_raise Enviable.ConversionError, conversion_error(type), fn ->
      convert_as(value, type, options)
    end
  end

  def assert_unsupported_conversion_error(reason, value, type) do
    assert_raise Enviable.UnsupportedConversionError, unsupported_conversion_error(type, reason), fn ->
      convert_as(value, type)
    end
  end

  def convert_as(value, type, options \\ []) do
    Conversion.convert_as(%Value{value: value, name: "VARNAME"}, type, options)
  end

  def split_lines(data) do
    data
    |> String.codepoints()
    |> Enum.chunk_every(80)
    |> Enum.map_join("\n", &Enum.join/1)
  end

  def trim_padding(data), do: String.trim_trailing(data, "=")

  def config_error(type, reason) do
    "could not convert environment variable \"VARNAME\" to type #{Errors.format_type(type)}: #{reason}"
  end

  def conversion_error(type) do
    "could not convert environment variable \"VARNAME\" to type #{type}"
  end

  def unsupported_conversion_error(type, reason) do
    "unsupported conversion #{Errors.format_type(type)}: #{reason}"
  end
end
