defmodule Enviable.Conversion do
  @moduledoc """
  All supported conversions and options for those conversions.
  """

  atom_options = """
  ### Options

  - `:allowed`: A list of `t:atom/0` values indicating permitted atoms and used as a lookup
    table, if present. Any value not found will result in an exception.
  - `:default`: The `t:atom/0` or `t:binary/0` value representing the atom value to use if
    the environment variable is unset (`nil`). If the `:allowed` option is present, the
    default value must be one of the permitted values.
  - `:downcase`: See `t:opt_downcase/0`.

  [pae]: https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion
  """

  @typedoc """
  Indicates a conversion to `t:atom/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_atom/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See [Preventing atom exhaustion][pae] from the
  > Security Working Group of the Erlang Ecosystem Foundation.

  #{atom_options}
  """
  @typedoc since: "1.1.0"
  @type convert_atom :: :atom

  @typedoc """
  Indicates a conversion to `t:atom/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_existing_atom/1` which wil result in an
  > exception if the resulting atom is not already known and if used without the
  > `:allowed` option. See [Preventing atom exhaustion][pae] from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{atom_options}
  """
  @typedoc since: "1.1.0"
  @type convert_safe_atom :: :safe_atom

  @typedoc """
  Indicates a conversion to `t:boolean/0`. This conversion will always result in a `true`
  or `false` value.

  ### Options

  - `:default`: The default value, which must be `true` or `false`. The default value is
    `false`.
  - `:downcase`: See `t:opt_downcase/0`.
  - `:truthy`, `:falsy`: Only one of `:truthy` or `:falsy` may be specified. It must be
    a list of `t:binary/0` values. If neither is specified, the default is `truthy: ~w[1
    true]`.
    - `:truthy`: if the value to convert is in this list, the result will be `true`
    - `:falsy`: if the value to convert is in this list, the result will be `false`
  """
  @typedoc since: "1.0.0"
  @type convert_boolean :: :boolean

  @typedoc """
  Indicates a conversion to `t:integer/0`.

  ### Options

  - `:base`: The base (an integer value `2..36`). Default is `10`.
  - `:default`: The default value. If specified as a `t:binary/0`, it must be expressed in
    the `:base` value and convert cleanly to an integer.
  """
  @typedoc since: "1.0.0"
  @type convert_integer :: :integer

  @typedoc """
  Indicates a conversion to `t:charlist/0`.

  ### Options

  - `:default`: The default value, either as a `t:charlist/0` or `t:binary/0`.
  """
  @typedoc since: "1.1.0"
  @type convert_charlist :: :charlist

  @typedoc """
  Indicates a conversion to `t:float/0`.

  ### Options

  - `:default`: The default value, either as `t:float/0`, `t:integer/0` (which will be
    converted to float), or `t:binary/0` (which must parse cleanly as float).
  """
  @typedoc since: "1.1.0"
  @type convert_float :: :float

  @typedoc """
  Indicates a conversion from JSON, which may result in `nil`, `t:binary/0`,
  `t:boolean/0`, `t:list/0`, `t:map/0`, or `t:number/0` values.

  ### Options

  - `:default`: The default value, which may be any valid JSON type.
  - `:engine`: The JSON engine to use. May be provided as a `t:module/0` (which must
    export `decode/1`) or an arity 1 function. If it produces `{:ok, json_value}` or an
    expected JSON type result, it will be considered successful. Any other result will be
    treated as failure.

  If the Erlang/OTP `m::json` module is available, or [json_polyfill][jp] is available,
  it will be used as the default JSON engine. Otherwise, [Jason][jason] will be treated as
  the default engine. This choice may be overridden with application configuration, as
  this example shows using [Thoas][thoas].

  ```elixir
  import Config

  config :enviable, :json_engine, :thoas
  ```

  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [thoas]: https://hexdocs.pm/thoas/readme.html
  """
  @typedoc since: "1.1.0"
  @type convert_json :: :json

  @typedoc """
  Indicates a conversion to log level atoms.

  This conversion is always case-insensitive, and the result will be one of `:emergency`,
  `:alert`, `:critical`, `:error`, `:warning`, `:warn`, `:notice`, `:info`, `:debug`,
  `:all`, or `:none` (values supported by `Logger.configure/1`).

  ### Options

  - `:default`: The default value. Must be one of the permitted values for
    `Logger.level/1` or `Logger.configure/1`.
  """
  @typedoc since: "1.2.0"
  @type convert_log_level :: :log_level

  @log_levels [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug, :all, :none]
  @log_levels_map Map.new(@log_levels, &{Atom.to_string(&1), &1})

  module_options = """

  ### Options

  - `:allowed`: A list of `t:module/0` values indicating permitted module and used as
    a lookup table, if present. Any value not found will result in an exception.
  - `:default`: The `t:module/0` or `t:binary/0` value representing the atom value to use
    if the environment variable is unset (`nil`). If the `:allowed` option is present, the
    default value must be one of the permitted values.

  [pae]: https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion
  """

  @typedoc """
  Indicates a conversion to `t:module/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.concat/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See [Preventing atom exhaustion][pae] from the
  > Security Working Group of the Erlang Ecosystem Foundation.

  #{module_options}
  """
  @typedoc since: "1.1.0"
  @type convert_module :: :module

  @typedoc """
  Indicates a conversion to `t:module/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.safe_concat/1` which wil result in an exception
  > if the resulting module is not already known and if used without the `:allowed`
  > option. See [Preventing atom exhaustion][pae] from the Security Working Group of the
  > Erlang Ecosystem Foundation.

  #{module_options}
  """
  @typedoc since: "1.1.0"
  @type convert_safe_module :: :safe_module

  @typedoc """
  Indicates a conversion from a PEM string through `:public_key.pem_decode/1`.

  ### Options

  - `:filter`: Filters the output of `:public_key.pem_decode/1`. Permitted values are
    `false`, `true`, `:cert`, or `:key`. The default is `true`.

    - `false`: the list is returned without processing, suitable for further processing
      with `:public_key.pem_entry_decode/2`.
    - `true`: returns the first unencrypted `:PrivateKeyInfo` found, a list of unencrypted
      `:Certificate` records, or an empty list.
    - `:cert`: returns a list of unencrypted `:Certificate` records or raises an
      exception if none are found.
    - `:key`: returns the first unencrypted `:PrivateKeyIinfo` record or raiuses an
      exception if one is not found.
  """
  @typedoc since: "1.1.0"
  @type convert_pem :: :pem

  @typedoc """
  Indicates a conversion from an Erlang term (`:erlang`) or an Elixir term (`:elixir`) by
  parsing and evaluating the environment variable value as code. This can be used for
  tuples, complex map declarations, or other expressions difficult to represent with other
  types.

  Longer code blocks should be encoded as base 64 text and decoded as `{:base64, :erlang}`
  or `{:base64, :elixir}`.

  > #### Untrusted Input {: .error}
  >
  > These conversion routnes parse and evaluate Erlang or Elixir code from environment
  > variables in the context of your application. Do not use this with untrusted code.
  >
  > - Erlang code is parsed with `:erl_scan.string/1` and `:erl_parse.parse_term/1`.
  > - Elixir code is parsed with `Code.string_to_quoted/1` and `Code.eval_quoted/1`.

  ## Examples

  ```elixir
  iex> Enviable.put_env("COLOR", "{ok, true}.")
  iex> Enviable.get_env_as("COLOR", :erlang)
  {:ok, true}

  iex> Enviable.put_env("PORT", "11000..11100//3")
  iex> Enviable.get_env_as("PORT", :elixir)
  11000..11100//3
  ```
  """
  @typedoc since: "1.1.0"
  @type convert_term :: :erlang | :elixir

  @typedoc since: "1.1.0"
  @type primitive ::
          convert_atom
          | convert_safe_atom
          | convert_boolean
          | convert_charlist
          | convert_float
          | convert_integer
          | convert_json
          | convert_module
          | convert_safe_module
          | convert_pem
          | convert_term

  @typedoc """
  Decodes the value from a base 16 encoded string. If a secondary type is provided,
  a further conversion pass is made using the secondary type.

  ### Options

  - `:case`: The value of `:case` passed to `Base.decode16/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_base16 :: :base16 | {:base16, :string | primitive}

  @typedoc """
  Decodes the value from a base 32 encoded string. If a secondary type is provided,
  a further conversion pass is made using the secondary type.

  ### Options

  - `:case`: The value of `:case` passed to `Base.decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`. The default is `:upper`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode32/2`. The default
    is `false` (the opposite of `Base.decode32/2`).

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_base32 :: :base32 | {:base32, :string | primitive}

  @typedoc """
  Decodes the value from a base 32 hex encoded string with extended hexadecimal alphabet.
  If a secondary type is provided, a further conversion pass is made using the secondary
  type.

  ### Options

  - `:case`: The value of `:case` passed to `Base.hex_decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`. The default is `:upper`.
  - `:padding`: The boolean value of `:padding` passed to `Base.hex_decode32/2`. The
    default is `false` (the opposite of `Base.hex_decode32/2`).

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_hex32 :: :hex32 | {:hex32, :string | primitive}

  @typedoc """
  Decodes the value from a base 64 encoded string. If a secondary type is provided,
  a further conversion pass is made using the secondary type.

  ### Options

  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_base64 :: :base64 | :url_base64 | {:base64 | :url_base64, :string | primitive}

  @typedoc since: "1.1.0"
  @type encoded :: encoded_base16 | encoded_base32 | encoded_hex32 | encoded_base64

  @typedoc since: "1.1.0"
  @type conversion :: primitive | encoded

  @typedoc """
  This option controls a type conversion's case folding mode passed to
  `String.downcase/2`.

  The default is `false`. `true` has the same meaning as `:default`.
  """
  @typedoc since: "1.0.0"
  @type opt_downcase :: {:downcase, true | false | :default | :ascii | :greek | :turkic}

  @spec convert_as(value :: nil | binary(), varname :: String.t(), conversion, keyword) :: nil | term()
  @doc false
  def convert_as(value, varname, {encoded, :string}, options) do
    convert_as(value, varname, encoded, options)
  end

  def convert_as(value, varname, {encoded, type}, options) do
    value
    |> convert_as(varname, encoded, options)
    |> convert_as(varname, type, options)
  end

  def convert_as(value, varname, type, options) do
    case config_for(type, options) do
      {:ok, config} ->
        value =
          if downcase = config[:downcase], do: String.downcase(value, downcase), else: value

        case convert_to(type, value, config) do
          {:ok, result} -> result
          :error -> raise Enviable.ConversionError, env: varname, type: type
        end

      {:error, reason} ->
        raise ArgumentError, "could not convert environment variable #{inspect(varname)} to type #{type}: #{reason}"
    end
  end

  defguardp is_json(value)
            when is_binary(value) or is_boolean(value) or is_list(value) or is_map(value) or is_nil(value) or
                   is_number(value)

  @spec convert_to(conversion, nil | binary(), map()) :: {:ok, nil | term()} | :error
  defp convert_to(_type, nil, %{default: default}) do
    {:ok, default}
  end

  defp convert_to(_type, nil, _config) do
    {:ok, nil}
  end

  defp convert_to(type, value, %{allowed: allowed})
       when type in [:atom, :module, :safe_atom, :safe_module] and is_map(allowed) do
    Map.fetch(allowed, value)
  end

  defp convert_to(:atom, value, _config) do
    {:ok, String.to_atom(value)}
  end

  defp convert_to(:boolean, value, config) do
    result =
      if config.truthy do
        value in config.truthy
      else
        value not in config.falsy
      end

    {:ok, result}
  end

  defp convert_to(:charlist, value, _config) do
    {:ok, String.to_charlist(value)}
  end

  defp convert_to(:float, value, _config) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end

  defp convert_to(:integer, value, %{base: base}) do
    case Integer.parse(value, base) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  defp convert_to(:json, value, %{engine: engine}) do
    case decode_json(value, engine) do
      value when is_json(value) -> {:ok, value}
      {:ok, value} when is_json(value) -> {:ok, value}
      _ -> :error
    end
  end

  defp convert_to(:log_level, value, _config) do
    Map.fetch(@log_levels_map, String.downcase(value))
  end

  defp convert_to(:module, value, _config) do
    {:ok, Module.concat([value])}
  end

  defp convert_to(:pem, value, %{filter: filter}) do
    entries = :public_key.pem_decode(value)

    case filter do
      false ->
        {:ok, entries}

      true ->
        {:ok, public_key_filter(entries)}

      :cert ->
        case Enum.filter(entries, &match?({:Certificate, _, :not_encrypted}, &1)) do
          [] -> :error
          certs -> {:ok, Enum.map(certs, &elem(&1, 1))}
        end

      :key ->
        case Enum.find(entries, &match?({:PrivateKeyInfo, _, :not_encrypted}, &1)) do
          nil -> :error
          {_, pk, _} -> {:ok, {:PrivateKeyInfo, pk}}
        end
    end
  end

  defp convert_to(:safe_atom, value, _config) do
    {:ok, String.to_existing_atom(value)}
  end

  defp convert_to(:safe_module, value, _config) do
    {:ok, Module.safe_concat([value])}
  end

  defp convert_to(:erlang, value, _config) do
    case :erl_scan.string(String.to_charlist(value)) do
      {:ok, term, _} ->
        case :erl_parse.parse_term(term) do
          {:ok, result} -> {:ok, result}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp convert_to(:elixir, value, _config) do
    case Code.string_to_quoted(value) do
      {:ok, quoted} ->
        {term, _binding} = Code.eval_quoted(quoted)
        {:ok, term}

      _ ->
        :error
    end
  end

  defp convert_to(:base16, value, %{decode_opts: opts}) do
    Base.decode16(value, opts)
  end

  defp convert_to(:base32, value, %{decode_opts: opts}) do
    Base.decode32(value, opts)
  end

  defp convert_to(:hex32, value, %{decode_opts: opts}) do
    Base.hex_decode32(value, opts)
  end

  defp convert_to(:base64, value, %{decode_opts: opts}) do
    Base.decode64(value, opts)
  end

  defp convert_to(:url_base64, value, %{decode_opts: opts}) do
    Base.url_decode64(value, opts)
  end

  @spec config_for(conversion, keyword) :: {:ok, map()} | {:error, String.t()}
  defp config_for(type, opts) when type in [:atom, :safe_atom] do
    with {:ok, downcase} <- opt_downcase(opts),
         {:ok, allowed} <- atom_allowed(opts),
         {:ok, default} <- atom_default(opts, allowed) do
      {:ok, %{downcase: downcase, default: default, allowed: allowed}}
    end
  end

  defp config_for(:boolean, opts) do
    with {:ok, {truthy, falsy}} <- boolean_matchers(opts),
         {:ok, downcase} <- opt_downcase(opts),
         {:ok, default} <- boolean_default(opts) do
      {:ok, %{default: default, downcase: downcase, falsy: falsy, truthy: truthy}}
    end
  end

  defp config_for(:charlist, opts) do
    case Keyword.fetch(opts, :default) do
      :error -> {:ok, %{default: nil}}
      {:ok, value} when is_binary(value) -> {:ok, %{default: String.to_charlist(value)}}
      {:ok, value} when is_list(value) -> {:ok, %{default: value}}
      _ -> {:error, "non-charlist `default` value"}
    end
  end

  defp config_for(:float, opts) do
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

  defp config_for(:log_level, opts) do
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

  defp config_for(:integer, opts) do
    with {:ok, base} <- integer_base(opts),
         {:ok, default} <- integer_default(opts, base) do
      {:ok, %{default: default, base: base}}
    end
  end

  defp config_for(:json, opts) do
    with {:ok, default} <- json_default(opts),
         {:ok, engine} <- json_engine(opts) do
      {:ok, %{default: default, engine: engine}}
    end
  end

  defp config_for(type, opts) when type in [:module, :safe_module] do
    with {:ok, allowed} <- module_allowed(opts),
         {:ok, default} <- atom_default(opts, allowed) do
      {:ok, %{default: default, allowed: allowed}}
    end
  end

  defp config_for(:pem, opts) do
    case Keyword.fetch(opts, :filter) do
      :error -> {:ok, %{filter: true}}
      {:ok, value} when value in [:cert, :key, false, true] -> {:ok, %{filter: value}}
      _ -> {:error, "invalid `filter` value"}
    end
  end

  defp config_for(type, _opts) when type in [:erlang, :elixir], do: {:ok, %{}}

  defp config_for(:base16, opts) do
    case encoded_case(opts) do
      {:ok, result} -> {:ok, %{decode_opts: result}}
      error -> error
    end
  end

  defp config_for(base32, opts) when base32 in [:base32, :hex32] do
    with {:ok, case_config} <- encoded_case(opts),
         {:ok, padding_config} <- encoded_padding(opts) do
      {:ok, %{decode_opts: Keyword.merge(case_config, padding_config)}}
    end
  end

  defp config_for(base64, opts) when base64 in [:base64, :url_base64] do
    with {:ok, whitespace_config} <- encoded_whitespace(opts),
         {:ok, padding_config} <- encoded_padding(opts) do
      {:ok, %{decode_opts: Keyword.merge(whitespace_config, padding_config)}}
    end
  end

  defp encoded_case(opts) do
    case Keyword.get(opts, :case, :upper) do
      value when value in [:upper, :lower, :mixed] -> {:ok, [case: value]}
      _ -> {:error, "invalid `case` value"}
    end
  end

  defp encoded_padding(opts) do
    case Keyword.get(opts, :padding, false) do
      value when is_boolean(value) -> {:ok, [padding: value]}
      _ -> {:error, "invalid `padding` value"}
    end
  end

  defp encoded_whitespace(opts) do
    case Keyword.get(opts, :ignore_whitespace, true) do
      true -> {:ok, ignore: :whitespace}
      false -> {:ok, []}
      _ -> {:error, "invalid `ignore_whitespace` value"}
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

  if Code.ensure_loaded?(:json) do
    @default_engine :json
  else
    @default_engine Jason
  end

  defp json_engine(opts) do
    case Keyword.fetch(opts, :engine) do
      :error -> {:ok, Application.get_env(:enviable, :json, @default_engine)}
      {:ok, engine} when is_atom(engine) or is_function(engine, 1) -> {:ok, engine}
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

  defp opt_downcase(opts) do
    case Keyword.get(opts, :downcase, false) do
      true -> {:ok, :default}
      atom when atom in [false, :default, :ascii, :greek, :turkic] -> {:ok, atom}
      _ -> {:error, "invalid `downcase` value"}
    end
  end

  defp decode_json(value, engine) when is_function(engine, 1) do
    engine.(value)
  rescue
    _ -> :error
  end

  defp decode_json(value, engine) when is_atom(engine) do
    engine.decode(value)
  rescue
    _ -> :error
  end

  defp public_key_filter([{:PrivateKeyInfo, pk, :not_encrypted} | _]), do: {:PrivateKeyInfo, pk}
  defp public_key_filter([{:Certificate, ct, :not_encrypted} | rest]), do: [ct | public_key_filter(rest)]
  defp public_key_filter([]), do: []
end
