defmodule Enviable.Conversion.Config do
  # Config parsing for conversion options

  @moduledoc false

  @boolean_downcase Application.compile_env(:enviable, :boolean_downcase, false)

  default_engine =
    if Code.ensure_loaded?(:json) do
      :json
    else
      Jason
    end

  @default_engine Application.compile_env(:enviable, :json_engine, default_engine)

  @log_levels [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug, :all, :none]
  @log_levels_map Map.new(@log_levels, &{Atom.to_string(&1), &1})

  @spec parse(Enviable.Conversion.conversion(), keyword) :: {:ok, map()} | {:error, String.t()}
  def parse(type, opts) when type in [:atom, :safe_atom] do
    with {:ok, casefold} <- opt_casefold(opts),
         {:ok, allowed} <- atom_allowed(opts),
         {:ok, default} <- atom_default(opts, allowed) do
      {:ok, %{casefold: casefold, default: default, allowed: allowed}}
    end
  end

  def parse(:boolean, opts) do
    with {:ok, {truthy, falsy}} <- boolean_matchers(opts),
         {:ok, casefold} <- opt_boolean_casefold(opts, @boolean_downcase),
         {:ok, default} <- boolean_default(opts) do
      {:ok, %{default: default, casefold: casefold, falsy: falsy, truthy: truthy}}
    end
  end

  def parse(:charlist, opts) do
    case Keyword.fetch(opts, :default) do
      :error -> {:ok, %{default: nil}}
      {:ok, value} when is_binary(value) -> {:ok, %{default: String.to_charlist(value)}}
      {:ok, value} when is_list(value) -> {:ok, %{default: value}}
      _ -> {:error, "non-charlist `default` value"}
    end
  end

  def parse(:float, opts) do
    case Keyword.fetch(opts, :default) do
      :error ->
        {:ok, %{default: nil}}

      {:ok, value} when is_float(value) ->
        {:ok, %{default: value}}

      {:ok, value} when is_integer(value) ->
        {:ok, %{default: value + 0.0}}

      {:ok, value} when is_binary(value) ->
        case Float.parse(value) do
          {float, ""} -> {:ok, %{default: float}}
          _ -> {:error, "non-float `default` value"}
        end

      _ ->
        {:error, "non-float `default` value"}
    end
  end

  def parse(:log_level, opts) do
    case Keyword.fetch(opts, :default) do
      :error ->
        {:ok, %{default: nil}}

      {:ok, value} when is_atom(value) and value in @log_levels ->
        {:ok, %{default: value}}

      {:ok, value} when is_binary(value) ->
        if level = @log_levels_map[value] do
          {:ok, %{default: level}}
        else
          {:error, "invalid `default` value #{value}"}
        end

      {:ok, value} ->
        {:error, "invalid `default` value #{inspect(value)}"}
    end
  end

  def parse(:integer, opts) do
    with {:ok, base} <- integer_base(opts),
         {:ok, default} <- integer_default(opts, base) do
      {:ok, %{default: default, base: base}}
    end
  end

  def parse(:json, opts) do
    with {:ok, default} <- json_default(opts),
         {:ok, engine} <- json_engine(opts) do
      {:ok, %{default: default, engine: engine}}
    end
  end

  def parse(type, opts) when type in [:module, :safe_module] do
    with {:ok, allowed} <- module_allowed(opts),
         {:ok, default} <- atom_default(opts, allowed) do
      {:ok, %{default: default, allowed: allowed}}
    end
  end

  def parse(:pem, opts) do
    case Keyword.fetch(opts, :filter) do
      :error -> {:ok, %{filter: true}}
      {:ok, value} when value in [:cert, :key, false, true] -> {:ok, %{filter: value}}
      _ -> {:error, "invalid `filter` value"}
    end
  end

  def parse(type, _opts) when type in [:erlang, :elixir], do: {:ok, %{}}

  def parse(:base16, opts), do: decode_opts(opts, :case)

  def parse(base32, opts) when base32 in [:base32, :hex32], do: decode_opts(opts, [:case, :padding])

  def parse(base64, opts) when base64 in [:base64, :url_base64], do: decode_opts(opts, [:whitespace, :padding])

  def parse(:list, opts) do
    with {:ok, config} <- decode_opts(opts, [:delimiter, :parts, :trim, :on, :include_captures]) do
      case Keyword.fetch(opts, :default) do
        :error -> {:ok, config}
        {:ok, value} when is_list(value) -> {:ok, Map.put(config, :default, value)}
        _ -> {:error, "non-list `default` value"}
      end
    end
  end

  defguardp is_json(value)
            when is_binary(value) or is_boolean(value) or is_list(value) or is_map(value) or is_nil(value) or
                   is_number(value)

  defp decode_opts(opts, keys) do
    result =
      keys
      |> List.wrap()
      |> Enum.reduce_while([], &decode_opt(opts, &1, &2))

    case result do
      {:error, reason} -> {:error, reason}
      result when is_list(result) -> {:ok, %{decode_opts: result}}
    end
  end

  defp decode_opt(opts, :case, decode_opts) do
    case Keyword.get(opts, :case, :upper) do
      value when value in [:upper, :lower, :mixed] -> {:cont, Keyword.put(decode_opts, :case, value)}
      _ -> {:halt, {:error, "invalid `case` value"}}
    end
  end

  defp decode_opt(opts, :padding, decode_opts) do
    case Keyword.get(opts, :padding, false) do
      value when is_boolean(value) -> {:cont, Keyword.put(decode_opts, :padding, value)}
      _ -> {:halt, {:error, "invalid `padding` value"}}
    end
  end

  defp decode_opt(opts, :whitespace, decode_opts) do
    case Keyword.get(opts, :ignore_whitespace, true) do
      true -> {:cont, Keyword.put(decode_opts, :ignore, :whitespace)}
      false -> {:cont, decode_opts}
      _ -> {:halt, {:error, "invalid `ignore_whitespace` value"}}
    end
  end

  defp decode_opt(opts, :delimiter, decode_opts) do
    case Keyword.get(opts, :delimiter, ",") do
      value when is_binary(value) or is_list(value) or is_struct(value, Regex) or is_tuple(value) ->
        {:cont, Keyword.put(decode_opts, :delimiter, value)}

      _ ->
        {:halt, {:error, "invalid `delimiter` value"}}
    end
  end

  defp decode_opt(opts, :parts, decode_opts) do
    case Keyword.fetch(opts, :parts) do
      :error -> {:cont, decode_opts}
      {:ok, :infinity} -> {:cont, Keyword.put(decode_opts, :parts, :infinity)}
      {:ok, value} when is_integer(value) and value > 0 -> {:cont, Keyword.put(decode_opts, :parts, value)}
      _ -> {:halt, {:error, "invalid `parts` value"}}
    end
  end

  defp decode_opt(opts, :trim, decode_opts) do
    case Keyword.fetch(opts, :trim) do
      :error -> {:cont, decode_opts}
      {:ok, value} when is_boolean(value) -> {:cont, Keyword.put(decode_opts, :trim, value)}
      _ -> {:halt, {:error, "invalid `trim` value"}}
    end
  end

  defp decode_opt(opts, :on, decode_opts) do
    case Keyword.fetch(opts, :on) do
      :error ->
        {:cont, decode_opts}

      {:ok, atom} when atom in [:all, :first, :all_but_first, :none, :all_names] ->
        {:cont, Keyword.put(decode_opts, :on, atom)}

      {:ok, list} when is_list(list) ->
        {:cont, Keyword.put(decode_opts, :on, list)}

      _ ->
        {:halt, {:error, "invalid `on` value"}}
    end
  end

  defp decode_opt(opts, :include_captures, decode_opts) do
    case Keyword.fetch(opts, :include_captures) do
      :error ->
        {:cont, decode_opts}

      {:ok, value} when is_boolean(value) ->
        {:cont, Keyword.put(decode_opts, :include_captures, value)}

      _ ->
        {:halt, {:error, "invalid `include_captures` value"}}
    end
  end

  defp atom_allowed(opts) do
    case Keyword.fetch(opts, :allowed) do
      :error ->
        {:ok, nil}

      {:ok, []} ->
        {:error, "`allowed` cannot be empty"}

      {:ok, [_ | _] = allowed} ->
        if Enum.all?(allowed, &is_atom/1) do
          {:ok, Map.new(allowed, &{Atom.to_string(&1), &1})}
        else
          {:error, "`allowed` must be an atom list"}
        end

      _ ->
        {:error, "`allowed` must be an atom list"}
    end
  end

  defp atom_default(opts, allowed) do
    case Keyword.fetch(opts, :default) do
      :error -> {:ok, nil}
      {:ok, value} -> atom_default_allowed(value, allowed)
    end
  end

  defp atom_default_allowed(value, nil) when is_atom(value), do: {:ok, value}

  defp atom_default_allowed(value, allowed) when is_atom(value) and is_map(allowed) do
    if value in Map.values(allowed) do
      {:ok, value}
    else
      {:error, "`default` value '#{value}' not present in `allowed`"}
    end
  end

  defp atom_default_allowed(value, allowed) when is_binary(value) and is_map(allowed) do
    if atom = allowed[value] do
      {:ok, atom}
    else
      {:error, "`default` value '#{value}' not present in `allowed`"}
    end
  end

  defp atom_default_allowed(_value, _allowed), do: {:error, "non-atom `default` value"}

  defp boolean_default(opts) do
    case Keyword.get(opts, :default, false) do
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, "non-boolean `default` value"}
    end
  end

  defp boolean_matchers(opts) do
    case {Keyword.get(opts, :truthy), Keyword.get(opts, :falsy)} do
      {nil, nil} -> {:ok, {~w[1 true], nil}}
      {[_ | _] = truthy, nil} -> {:ok, {truthy, nil}}
      {nil, [_ | _] = falsy} -> {:ok, {nil, falsy}}
      _ -> {:error, "`truthy` and `falsy` options both provided"}
    end
  end

  defp integer_base(opts) do
    case Keyword.get(opts, :base, 10) do
      base when is_integer(base) and base >= 2 and base <= 36 -> {:ok, base}
      _ -> {:error, "invalid `base` value (must be an integer 2..36)"}
    end
  end

  defp integer_default(opts, base) do
    case Keyword.fetch(opts, :default) do
      :error ->
        {:ok, nil}

      {:ok, value} when is_integer(value) ->
        {:ok, value}

      {:ok, value} when is_binary(value) ->
        case Integer.parse(value, base) do
          {integer, ""} -> {:ok, integer}
          _ -> {:error, "non-integer `default` value for base #{base}"}
        end

      _ ->
        {:error, "non-integer `default` value"}
    end
  end

  defp json_default(opts) do
    case Keyword.fetch(opts, :default) do
      :error -> {:ok, nil}
      {:ok, value} when is_json(value) -> {:ok, value}
      _ -> {:error, "non-JSON `default` value"}
    end
  end

  defp json_engine(opts) do
    case Keyword.fetch(opts, :engine) do
      :error -> {:ok, @default_engine}
      {:ok, engine} when is_atom(engine) or is_function(engine, 1) -> {:ok, engine}
      {:ok, {m, f, a} = engine} when is_atom(m) and is_atom(f) and is_list(a) -> {:ok, engine}
      _ -> {:error, "invalid `engine` value"}
    end
  end

  defp module_allowed(opts) do
    case atom_allowed(opts) do
      {:ok, allowed} -> {:ok, module_lookup(allowed)}
      error -> error
    end
  end

  defp module_lookup(nil), do: nil

  defp module_lookup(allowed) do
    allowed
    |> Enum.flat_map(fn {key, mod} -> [{key, mod}, {String.replace_prefix(key, "Elixir.", ""), mod}] end)
    |> Map.new()
  end

  defp opt_boolean_casefold(opts, default) do
    case Keyword.get(opts, :downcase, default) do
      true -> {:ok, {:downcase, :default}}
      atom when atom in [false, :default, :ascii, :greek, :turkic] -> {:ok, {:downcase, atom}}
      _ -> {:error, "invalid `downcase` value"}
    end
  end

  defp opt_casefold(opts) do
    case {Keyword.fetch(opts, :downcase), Keyword.fetch(opts, :upcase)} do
      {:error, :error} ->
        {:ok, {:downcase, false}}

      {{:ok, _}, {:ok, _}} ->
        {:error, "`downcase` and `upcase` options both provided"}

      {{:ok, true}, _} ->
        {:ok, {:downcase, :default}}

      {{:ok, value}, _} when value in [false, :default, :ascii, :greek, :turkic] ->
        {:ok, {:downcase, value}}

      {{:ok, _}, _} ->
        {:error, "invalid `downcase` value"}

      {_, {:ok, true}} ->
        {:ok, {:upcase, :default}}

      {_, {:ok, value}} when value in [false, :default, :ascii, :greek, :turkic] ->
        {:ok, {:upcase, value}}

      {_, {:ok, _}} ->
        {:error, "invalid `upcase` value"}
    end
  end
end
