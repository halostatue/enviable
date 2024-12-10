defmodule Enviable.Integer do
  @moduledoc false

  @type options :: [{:base, 2..36} | {:default, nil | binary() | integer()}]
  @type config :: %{
          required(:base) => 2..36,
          optional(:default) => nil | integer()
        }

  @spec get_env_integer(String.t(), options) :: nil | integer()
  def get_env_integer(varname, opts \\ []) do
    config = init!(:get_env_integer, opts)

    case System.fetch_env(varname) do
      :error ->
        config.default

      {:ok, value} ->
        case parse(value, config) do
          :error -> raise Enviable.ConversionError, env: varname, type: :integer
          {:ok, result} -> result
        end
    end
  end

  @spec fetch_env_integer(String.t(), options) :: {:ok, integer()} | :error
  def fetch_env_integer(varname, opts \\ []) do
    config = init!(:fetch_env_integer, opts)

    case System.fetch_env(varname) do
      :error -> :error
      {:ok, value} -> parse(value, config)
    end
  end

  @spec fetch_env_integer!(String.t(), options) :: integer()
  def fetch_env_integer!(varname, opts \\ []) do
    config = init!(:fetch_env_integer!, opts)

    case System.fetch_env(varname) do
      :error ->
        raise System.EnvError, env: varname

      {:ok, value} ->
        case parse(value, config) do
          :error -> raise Enviable.ConversionError, env: varname, type: :integer
          {:ok, result} -> result
        end
    end
  end

  @spec parse(binary(), config) :: {:ok, integer()} | :error
  defp parse(value, %{base: base}) do
    case Integer.parse(value, base) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  @spec init!(:get_env_integer | :fetch_env_integer | :fetch_env_integer!, options) :: config
  defp init!(fun, opts) do
    config =
      case base!(opts) do
        :error -> raise ArgumentError, "cannot execute Enviable.#{fun}/2 with invalid `base` value"
        value -> %{base: value}
      end

    if fun == :get_env_integer do
      case default!(opts, config.base) do
        :error ->
          raise ArgumentError,
                "cannot execute Enviable.#{fun}/2 with non-integer `default` value"

        value ->
          Map.put(config, :default, value)
      end
    else
      config
    end
  end

  @spec base!([{:base, 2..36}]) :: 2..36 | :error
  defp base!(opts) do
    case Keyword.get(opts, :base, 10) do
      value when value >= 2 and value <= 36 -> value
      _ -> :error
    end
  end

  @spec default!([{:default, nil | binary() | integer()}], 2..36) :: nil | integer() | :error
  defp default!(opts, base) do
    case Keyword.get(opts, :default) do
      nil ->
        nil

      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value, base) do
          {integer, ""} -> integer
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
