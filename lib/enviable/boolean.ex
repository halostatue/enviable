defmodule Enviable.Boolean do
  @moduledoc false

  @type mode :: false | :default | :ascii | :greek | :turkic
  @type options ::
          [
            {:default, boolean()}
            | {:downcase, true | mode}
            | {:falsy, list(binary())}
            | {:truthy, list(binary())}
          ]
  @typep config :: %{
           optional(:default) => boolean(),
           required(:downcase) => mode,
           required(:falsy) => nil | list(binary()),
           required(:truthy) => nil | list(binary())
         }

  @spec get_env_boolean(String.t(), options) :: boolean()
  def get_env_boolean(varname, opts \\ []) do
    config = init!(:get_env_boolean, opts)

    case System.fetch_env(varname) do
      :error -> config.default
      {:ok, value} -> parse(value, config)
    end
  end

  @spec fetch_env_boolean(String.t(), options) :: {:ok, boolean()} | :error
  def fetch_env_boolean(varname, opts \\ []) do
    config = init!(:fetch_env_boolean, opts)

    case System.fetch_env(varname) do
      :error -> :error
      {:ok, value} -> {:ok, parse(value, config)}
    end
  end

  @spec fetch_env_boolean!(String.t(), options) :: boolean()
  def fetch_env_boolean!(varname, opts \\ []) do
    config = init!(:fetch_env_boolean!, opts)

    case System.fetch_env(varname) do
      :error -> raise System.EnvError, env: varname
      {:ok, value} -> parse(value, config)
    end
  end

  @spec parse(binary(), config) :: boolean()
  defp parse(value, config) do
    value =
      if config.downcase do
        String.downcase(value, config.downcase)
      else
        value
      end

    if config.truthy do
      value in config.truthy
    else
      value not in config.falsy
    end
  end

  @spec init!(:get_env_boolean | :fetch_env_boolean | :fetch_env_boolean!, options) ::
          config
  defp init!(fun, opts) do
    config =
      case matchers!(opts) do
        :error ->
          raise ArgumentError,
                "cannot execute Enviable.#{fun}/2 with both `truthy` and `falsy` options"

        {truthy, falsy} ->
          %{truthy: truthy, falsy: falsy}
      end

    config =
      case downcase!(opts) do
        :error ->
          raise ArgumentError,
                "cannot execute Enviable.#{fun}/2 with invalid `downcase` value"

        value ->
          Map.put(config, :downcase, value)
      end

    if fun == :get_env_boolean do
      case default!(opts) do
        :error ->
          raise ArgumentError,
                "cannot execute Enviable.#{fun}/2 with non-boolean `default` value"

        value ->
          Map.put(config, :default, value)
      end
    else
      config
    end
  end

  @spec downcase!([{:downcase, true | mode}]) :: mode | :error
  defp downcase!(opts) do
    case Keyword.get(opts, :downcase, false) do
      true -> :default
      false -> false
      atom when atom in [:default, :ascii, :greek, :turkic] -> atom
      _ -> :error
    end
  end

  @spec matchers!([{:falsy, list(binary())} | {:truthy, list(binary())}]) ::
          {list(binary()), nil} | {nil, list(binary())} | :error
  defp matchers!(opts) do
    case {Keyword.get(opts, :truthy), Keyword.get(opts, :falsy)} do
      {nil, nil} -> {~w[1 true], nil}
      {[_ | _] = truthy, nil} -> {truthy, nil}
      {nil, [_ | _] = falsy} -> {nil, falsy}
      _ -> :error
    end
  end

  @spec default!([{:default, boolean()}]) :: boolean() | :error
  defp default!(opts) do
    case Keyword.get(opts, :default, false) do
      value when is_boolean(value) -> value
      _ -> :error
    end
  end
end
