defmodule Enviable.Conversion do
  @moduledoc """
  All supported conversions and options for those conversions.
  """

  alias Enviable.Conversion.Config, as: ECC

  atom_exhaustion =
    "[Preventing atom exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)"

  atom_options = """
  ### Options

  - `:allowed`: A list of `t:atom/0` values indicating permitted atoms and used as a lookup
    table, if present. Any value not found will result in an exception.
  - `:default`: The `t:atom/0` or `t:binary/0` value representing the atom value to use if
    the environment variable is unset (`nil`). If the `:allowed` option is present, the
    default value must be one of the permitted values.
  - `:downcase`: See `t:opt_downcase/0`.
  - `:upcase`: See `t:opt_upcase/0`.
  """

  @typedoc """
  Indicates a conversion to `t:atom/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion uses `String.to_atom/1` and may result in atom exhaustion if used
  > without the `:allowed` option. See #{atom_exhaustion} from the Security Working Group
  > of the Erlang Ecosystem Foundation.

  #{atom_options}
  """
  @typedoc since: "1.1.0"
  @type convert_atom :: :atom

  @typedoc """
  Indicates a conversion to `t:atom/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion uses `String.to_existing_atom/1` which will result in an exception if
  > the resulting atom is not already known and if used without the `:allowed` option. See
  > #{atom_exhaustion} from the Security Working Group of the Erlang Ecosystem Foundation.

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
  - `:downcase`: This option controls a type conversion's case folding mode passed to
    `String.downcase/2`. The default is `false`. `true` has the same meaning as
    `:default`.

    The default `:downcase` value for boolean conversions can be changed at compile time
    through application configuration:

    ```elixir
    config :enviable, :boolean_downcase, true
    config :enviable, :boolean_downcase, :default
    config :enviable, :boolean_downcase, :ascii
    ```

    > In the next major version of Enviable, the default `:downcase` value will be
    > changing to `:default`.

  - `:truthy`, `:falsy`: Only one of `:truthy` or `:falsy` may be specified. It must be
    a list of `t:binary/0` values. If neither is specified, the default is `truthy: ~w[1
    true]`.

    - `:truthy`: if the value to convert is in this list, the result will be `true`

    - `:falsy`: if the value to convert is in this list, the result will be `false`

  >
  > In a future version of Enviable, the default value of `:downcase` for boolean
  > conversions will change from `false` to `true`.
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
  Indicates a conversion to `t:Decimal.t/0`.

  ### Options

  - `:default`: The default value, either as `t:Decimal.t/0`, `t:float/0`, `t:integer/0`,
    or `t:binary/0` (the latter three must convert cleanly to `t:Decimal.t/0`).
  """
  @typedoc since: "1.6.0"
  @type convert_decimal :: :decimal

  @typedoc """
  Indicates a conversion to `t:float/0`.

  ### Options

  - `:default`: The default value, either as `t:float/0`, `t:integer/0` (which will be
    converted to float), or `t:binary/0` (which must parse cleanly as float).
  """
  @typedoc since: "1.1.0"
  @type convert_float :: :float

  @typedoc """
  A value which can be serialized from JSON.
  """
  @type json ::
          nil
          | String.t()
          | boolean()
          | number()
          | list(json)
          | %{optional(String.t()) => json}

  @typedoc """
  Indicates a conversion from JSON, which may result in `nil`, `t:binary/0`,
  `t:boolean/0`, `t:list/0`, `t:map/0`, or `t:number/0` values.

  ### Options

  - `:default`: The default value, which may be any valid JSON type.
  - `:engine`: The JSON engine to use. May be provided as a `t:module/0` (which must
    export `decode/1`), an arity 1 function, or a `t:mfa/0` tuple. When provided with
    a `t:mfa/0`, the variable value will be passed as the first parameter.

    If the engine produces `{:ok, json_value}` or an expected JSON type result, it will be
    considered successful. Any other result will be treated as failure.

    The default JSON module is selected from the `:enviable` application configuration
    option `:json_engine`. If this is unset, the default value is one of the following,
    in order:

    - [`JSON`][elixir-json] if the Elixir `m:JSON` module is available (Elixir 1.18+)
    - `:json` if the Erlang/OTP 27+ `m::json` module is available or if
      [json_polyfill][jp] is installed
    -  [Jason][jason]

    This example shows using [Thoas][thoas] as the JSON engine..

    ```elixir
    import Config

    config :enviable, :json_engine, :thoas
    ```

  [elixir-json]: https://hexdocs.pm/elixir/JSON.html
  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [thoas]: https://hexdocs.pm/thoas/readme.html
  """
  @typedoc since: "1.1.0"
  @type convert_json :: :json

  @typedoc """
  Indicates a conversion to log level `t:atom/0` for `Logger.configure/1`.

  This conversion is always case-insensitive, and the result will be one of `:emergency`,
  `:alert`, `:critical`, `:error`, `:warning`, `:warn`, `:notice`, `:info`, `:debug`,
  `:all`, or `:none`.

  ### Options

  - `:default`: The default atom value. Must be a valid value.
  """
  @typedoc since: "1.2.0"
  @type convert_log_level :: :log_level

  @typedoc """
  Supported log levels.
  """
  @typedoc since: "1.3.0"
  @type log_level :: Logger.level() | :all | :none

  @log_levels [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug, :all, :none]
  @log_levels_map Map.new(@log_levels, &{Atom.to_string(&1), &1})

  module_options = """

  ### Options

  - `:allowed`: A list of `t:module/0` values indicating permitted module and used as
    a lookup table, if present. Any value not found will result in an exception.
  - `:default`: The `t:module/0` or `t:binary/0` value representing the atom value to use
    if the environment variable is unset (`nil`). If the `:allowed` option is present, the
    default value must be one of the permitted values.
  """

  @typedoc """
  Indicates a conversion to `t:module/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion uses `Module.concat/1` and may result in atom exhaustion if used
  > without the `:allowed` option. See #{atom_exhaustion} from the Security Working Group
  > of the Erlang Ecosystem Foundation.

  #{module_options}
  """
  @typedoc since: "1.1.0"
  @type convert_module :: :module

  @typedoc """
  Indicates a conversion to `t:module/0`.

  > #### Untrusted Input {: .warning}
  >
  > This conversion uses `Module.safe_concat/1` which will result in an exception if the
  > resulting module is not already known and if used without the `:allowed` option. See
  > #{atom_exhaustion} from the Security Working Group of the Erlang Ecosystem Foundation.

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
    - `:key`: returns the first unencrypted `:PrivateKeyIinfo` record or raises an
      exception if one is not found.
  """
  @typedoc since: "1.1.0"
  @type convert_pem :: :pem

  @typedoc """
  Possible return types for `t:convert_pem/0` conversions.

  The return types are variant on the conversion `:filter` option value:

  - `true`: either an unencrypted primary key `t:binary/0`  or a list of unencrypted
    certificates (`[{:Certificate, ct, :not_encrypted}]`);
  - `false`: an unmodified list of `t::public_key.pem_entry/0`.
  - `:cert`: list of unencrypted certificates (`[{:Certificate, ct, :not_encrypted}]`).
  - `:key`: unencrypted primary key `t:binary/0`

  The default is `true`.
  """
  @typedoc since: "1.3.0"
  @type pem ::
          [:public_key.pem_entry()]
          | binary()
          | [{:Certificate, binary(), :not_encrypted}]

  @typedoc """
  Indicates a conversion from a Erlang code string (`:erlang`) by parsing and evaluating
  the environment variable value.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded as `{:base64, :erlang}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `:erl_scan.string/1`) and evaluates (with
  > `:erl_parse.parse_term/1`) Erlang code from environment variables in the
  > context of your application. Do not use this with untrusted input.

  ## Examples

  ```elixir
  iex> Enviable.put_env("COLOR", "{ok, true}.")
  iex> Enviable.get_env_as("COLOR", :erlang)
  {:ok, true}
  ```
  """
  @typedoc since: "1.1.0"
  @type convert_erlang :: :erlang

  @typedoc """
  Indicates a conversion from a Elixir code string (`:elixir`) by parsing and evaluating
  the environment variable value.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded as `{:base64, :elixir}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `Code.string_to_quoted/1`) and evaluates (with
  > `Code.eval_quoted/1`) elixir code from environment variables in the context of your
  > application. Do not use this with untrusted input.

  ## Examples

  ```elixir
  iex> Enviable.put_env("PORT", "11000..11100//3")
  iex> Enviable.get_env_as("PORT", :elixir)
  11000..11100//3
  ```
  """
  @typedoc since: "1.3.0"
  @type convert_elixir :: :elixir

  @typedoc since: "1.1.0"
  @type primitive ::
          convert_atom
          | convert_boolean
          | convert_charlist
          | convert_decimal
          | convert_elixir
          | convert_erlang
          | convert_float
          | convert_integer
          | convert_json
          | convert_module
          | convert_pem
          | convert_safe_atom
          | convert_safe_module

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

  @typedoc """
  Decodes the value from a string as a delimiter-separated list. If a secondary type is
  provided, a further conversion pass is made using the secondary type.

  ### Options

  - `:delimiter`: The delimiter used to separate the list. This must be a pattern accepted
    by `String.split/3` (a string, a list of strings, a compiled binary pattern, or
    a regular expression). Defaults to `","`.
  - `:parts`: The maximum number of parts to split into (`t:pos_integer/0` or
    `:infinity`). Passed to `String.split/3`.
  - `:trim`: A boolean option whether empty entries should be omitted.

  When the pattern is a regular expression, `Regex.split/3` options are also supported:

  - `:on`: specifies which captures to split the string on, and in what order. Defaults to
    :first which means captures inside the regex do not affect the splitting process.
  - `:include_captures`: when true, includes in the result the matches of the regular
    expression. The matches are not counted towards the maximum number of parts if
    combined with the `:parts` option. Defaults to `false`.

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.4.0"
  @type encoded_list :: :list | {:list, :string | primitive}

  @typedoc since: "1.1.0"
  @type encoded :: encoded_base16 | encoded_base32 | encoded_hex32 | encoded_base64 | encoded_list

  @typedoc since: "1.1.0"
  @type conversion :: primitive | encoded

  @typedoc """
  This option controls a type conversion's case folding mode passed to
  `String.downcase/2`.

  The default is `false`. `true` has the same meaning as `:default`.

  This is mutually exclusive with `upcase`.
  """
  @typedoc since: "1.0.0"
  @type opt_downcase :: {:downcase, true | false | :default | :ascii | :greek | :turkic}

  @typedoc """
  This option controls a type conversion's case folding mode passed to
  `String.upcase/2`.

  The default is `false`. `true` has the same meaning as `:default`.

  This is mutually exclusive with `downcase`.
  """
  @typedoc since: "1.5.0"
  @type opt_upcase :: {:upcase, true | false | :default | :ascii | :greek | :turkic}

  @spec convert_as(value :: nil | binary(), varname :: String.t(), conversion, keyword) :: nil | term()
  @doc false
  def convert_as(value, varname, {encoded, :string}, options) do
    convert_as(value, varname, encoded, options)
  end

  def convert_as(value, varname, {:list, type}, options) do
    value
    |> convert_as(varname, :list, options)
    |> Enum.with_index()
    |> Enum.map(fn {value, index} -> convert_as(value, "#{varname}[#{index}]", type, options) end)
  end

  def convert_as(value, varname, {encoded, type}, options) do
    value
    |> convert_as(varname, encoded, options)
    |> convert_as(varname, type, options)
  end

  def convert_as(value, varname, type, options) do
    case ECC.parse(type, options) do
      {:ok, config} ->
        value = casefold(value, config[:casefold])

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

  defp convert_to(:decimal, value, _config) do
    case Decimal.parse(value) do
      {decimal, ""} -> {:ok, decimal}
      _ -> :error
    end
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

  defp convert_to(:list, value, %{decode_opts: opts}) do
    {delimiter, opts} = Keyword.pop(opts, :delimiter)
    {:ok, String.split(value, delimiter, opts)}
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

  defp decode_json(value, {m, f, a}) do
    apply(m, f, [value | a])
  rescue
    _ -> :error
  end

  defp public_key_filter([{:PrivateKeyInfo, pk, :not_encrypted} | _]), do: {:PrivateKeyInfo, pk}
  defp public_key_filter([{:Certificate, ct, :not_encrypted} | rest]), do: [ct | public_key_filter(rest)]
  defp public_key_filter([]), do: []

  defp casefold(nil, _config), do: nil
  defp casefold(value, nil), do: value
  defp casefold(value, {_foldtype, false}), do: value
  defp casefold(value, {:upcase, type}), do: String.upcase(value, type)
  defp casefold(value, {:downcase, type}), do: String.downcase(value, type)
end
