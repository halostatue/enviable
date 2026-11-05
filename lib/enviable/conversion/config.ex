defmodule Enviable.Conversion.Config do
  # Conversion option validation and preparation.
  #
  # parse/2 validates the options for a single conversion layer against its schema
  # (Enviable.Conversion.Schema), then applies the checks and preparation that a schema
  # cannot express:
  #
  # - cross-key constraints (`downcase` vs `upcase`, `truthy` vs `falsy`, non-empty
  #   `allowed`, `default` in `allowed`)
  # - default coercion (`"3.5"` to `3.5` for `:float`, `[hour: 1]` to `3_600_000` for
  #   `:timeout`)
  # - lookup tables (`allowed`)
  # - compile-time configuration defaults (`:boolean_downcase`, `:json_engine`)
  #
  # Error reasons never include `:default` values, which may be secrets.
  #
  # List defaults are not prepared here. A list default is converted (or checked) by
  # Enviable.Conversion only when the value is unset, using the element type's config.

  @moduledoc false

  alias Enviable.Conversion.Schema
  alias Enviable.Conversion.TimeoutParser

  @boolean_downcase Application.compile_env(:enviable, :boolean_downcase, :default)

  default_engine =
    cond do
      Code.ensure_loaded?(JSON) -> JSON
      Code.ensure_loaded?(:json) -> :json
      true -> Jason
    end

  @default_engine Application.compile_env(:enviable, :json_engine, default_engine)

  @log_levels [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug, :all, :none]
  @log_levels_map Map.new(@log_levels, &{Atom.to_string(&1), &1})

  @typedoc "An error: the failing option key (or keys), and a reason without option values."
  @type error :: {:error, nil | atom() | [atom()], String.t()}

  @doc """
  Validates and prepares the options for a single conversion layer.
  """
  @spec parse(atom(), keyword()) :: {:ok, map()} | error()
  def parse(type, opts) do
    with {:ok, opts} <- Schema.validate(type, opts) do
      prepare(type, Map.new(opts))
    end
  end

  @doc """
  Prepares `value` as a `:default` for `type` using a config returned by parse/2. Used for
  the elements of non-string list defaults.
  """
  @spec prepare_default(atom(), term(), map()) :: {:ok, term()} | error()
  def prepare_default(type, value, config) do
    with {:ok, validated} <- Schema.validate(type, default: value) do
      default(type, Keyword.fetch!(validated, :default), config)
    end
  end

  # --- preparation

  defp prepare(type, opts) when type in [:atom, :safe_atom, :module, :safe_module] do
    with {:ok, casefold} <- casefold(opts),
         {:ok, allowed} <- allowed(type, opts) do
      config = %{casefold: casefold, allowed: allowed}
      with_default(type, opts, config, nil)
    end
  end

  defp prepare(:boolean, opts) do
    with {:ok, {truthy, falsy}} <- boolean_matchers(opts) do
      config = %{
        casefold: {:downcase, boolean_casefold(Map.get(opts, :downcase, @boolean_downcase))},
        truthy: truthy,
        falsy: falsy
      }

      with_default(:boolean, opts, config, false)
    end
  end

  defp prepare(:integer, opts), do: with_default(:integer, opts, %{base: opts.base}, nil)

  defp prepare(:json, opts), do: with_default(:json, opts, %{engine: Map.get(opts, :engine, @default_engine)}, nil)

  defp prepare(:pem, opts), do: {:ok, %{filter: opts.filter}}

  defp prepare(:timeout, opts), do: with_default(:timeout, opts, %{}, :infinity)

  defp prepare(type, _opts) when type in [:erlang, :elixir], do: {:ok, %{}}

  defp prepare(:base16, opts), do: {:ok, %{decode_opts: [case: opts.case]}}

  defp prepare(type, opts) when type in [:base32, :hex32],
    do: {:ok, %{decode_opts: [case: opts.case, padding: opts.padding]}}

  defp prepare(type, opts) when type in [:base64, :url_base64] do
    decode_opts = if opts.ignore_whitespace, do: [ignore: :whitespace], else: []
    {:ok, %{decode_opts: decode_opts ++ [padding: opts.padding]}}
  end

  defp prepare(:list, opts) do
    split_opts =
      opts
      |> Map.take([:parts, :trim, :on, :include_captures])
      |> Enum.sort()

    {:ok, %{delimiter: opts.delimiter, split_opts: split_opts}}
  end

  defp prepare(type, opts), do: with_default(type, opts, %{}, nil)

  defp with_default(type, opts, config, unset) do
    case Map.fetch(opts, :default) do
      :error ->
        {:ok, Map.put(config, :default, unset)}

      {:ok, value} ->
        with {:ok, default} <- default(type, value, config) do
          {:ok, Map.put(config, :default, default)}
        end
    end
  end

  # --- defaults

  defp default(type, value, %{allowed: allowed}) when is_map(allowed) and type in [:atom, :safe_atom] do
    lookup = if is_atom(value), do: Atom.to_string(value), else: value
    allowed_default(allowed, lookup)
  end

  defp default(type, value, %{allowed: allowed}) when is_map(allowed) and type in [:module, :safe_module] do
    lookup = if is_atom(value), do: inspect(value), else: value
    allowed_default(allowed, lookup)
  end

  defp default(type, value, _config) when type in [:atom, :safe_atom, :module, :safe_module] and is_atom(value),
    do: {:ok, value}

  # sobelow_skip ["DOS.StringToAtom"]
  defp default(:atom, value, _config) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    {:ok, String.to_atom(value)}
  end

  defp default(:safe_atom, value, _config) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> {:error, :default, "`:default` is not an existing atom"}
  end

  # sobelow_skip ["DOS.ModuleConcat"]
  defp default(:module, value, _config) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    {:ok, Module.concat([value])}
  end

  defp default(:safe_module, value, _config) do
    {:ok, Module.safe_concat([value])}
  rescue
    ArgumentError -> {:error, :default, "`:default` is not an existing module"}
  end

  defp default(:charlist, value, _config) when is_binary(value), do: {:ok, String.to_charlist(value)}

  defp default(:decimal, value, _config) when is_struct(value), do: {:ok, value}
  defp default(:decimal, value, _config) when is_integer(value), do: {:ok, Decimal.new(value)}
  defp default(:decimal, value, _config) when is_float(value), do: {:ok, Decimal.from_float(value)}

  defp default(:decimal, value, _config) do
    case Decimal.parse(value) do
      {decimal, ""} -> {:ok, decimal}
      _ -> {:error, :default, "`:default` is not a valid decimal"}
    end
  end

  defp default(:duration, value, _config) when is_binary(value) do
    case Duration.from_iso8601(value) do
      {:ok, duration} -> {:ok, duration}
      _ -> {:error, :default, "`:default` is not a valid ISO 8601 duration"}
    end
  end

  defp default(:float, value, _config) when is_integer(value), do: {:ok, value + 0.0}

  defp default(:float, value, _config) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :default, "`:default` is not a valid float"}
    end
  end

  defp default(:integer, value, %{base: base}) when is_binary(value) do
    case Integer.parse(value, base) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, :default, "`:default` is not a valid base #{base} integer"}
    end
  end

  defp default(:log_level, value, _config) when is_binary(value) do
    case Map.fetch(@log_levels_map, String.downcase(value)) do
      {:ok, level} -> {:ok, level}
      :error -> {:error, :default, "`:default` is not a valid log level"}
    end
  end

  defp default(:timeout, :infinity, _config), do: {:ok, :infinity}
  defp default(:timeout, value, _config) when is_binary(value), do: timeout_default(value)

  defp default(:timeout, value, _config) do
    {:ok, to_timeout(value)}
  rescue
    ArgumentError -> {:error, :default, "`:default` is not a valid timeout"}
  end

  defp default(_type, value, _config), do: {:ok, value}

  defp allowed_default(allowed, lookup) do
    case Map.fetch(allowed, lookup) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :default, "`:default` is not present in `:allowed`"}
    end
  end

  defp timeout_default(value) do
    case Duration.from_iso8601(value) do
      {:ok, duration} ->
        {:ok, to_timeout(duration)}

      _ ->
        case TimeoutParser.parse(value) do
          {:ok, parsed} -> {:ok, to_timeout(parsed)}
          _ -> {:error, :default, "`:default` is not a valid timeout"}
        end
    end
  end

  # --- cross-key checks and lookup tables

  defp casefold(%{downcase: _, upcase: _}),
    do: {:error, [:downcase, :upcase], "`:downcase` and `:upcase` are mutually exclusive"}

  defp casefold(%{downcase: mode}), do: {:ok, {:downcase, casefold_mode(mode)}}
  defp casefold(%{upcase: mode}), do: {:ok, {:upcase, casefold_mode(mode)}}
  defp casefold(_opts), do: {:ok, {:downcase, false}}

  defp casefold_mode(true), do: :default
  defp casefold_mode(mode), do: mode

  defp boolean_casefold(true), do: :default
  defp boolean_casefold(mode), do: mode

  defp allowed(_type, %{allowed: []}), do: {:error, :allowed, "`:allowed` cannot be empty"}

  defp allowed(type, %{allowed: allowed}) when type in [:atom, :safe_atom],
    do: {:ok, Map.new(allowed, &{Atom.to_string(&1), &1})}

  defp allowed(type, %{allowed: allowed}) when type in [:module, :safe_module] do
    lookup =
      Enum.flat_map(allowed, fn module ->
        key = Atom.to_string(module)
        [{key, module}, {String.replace_prefix(key, "Elixir.", ""), module}]
      end)

    {:ok, Map.new(lookup)}
  end

  defp allowed(_type, _opts), do: {:ok, nil}

  defp boolean_matchers(%{truthy: _, falsy: _}),
    do: {:error, [:truthy, :falsy], "`:truthy` and `:falsy` are mutually exclusive"}

  defp boolean_matchers(%{truthy: []}), do: {:error, :truthy, "`:truthy` cannot be empty"}
  defp boolean_matchers(%{falsy: []}), do: {:error, :falsy, "`:falsy` cannot be empty"}
  defp boolean_matchers(%{truthy: truthy}), do: {:ok, {truthy, nil}}
  defp boolean_matchers(%{falsy: falsy}), do: {:ok, {nil, falsy}}
  defp boolean_matchers(_opts), do: {:ok, {~w[1 true], nil}}
end
