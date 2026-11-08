defmodule Enviable.Conversion do
  @moduledoc """
  All supported conversions and options for those conversions.
  """

  alias Enviable.Conversion.Config
  alias Enviable.Conversion.Schema
  alias Enviable.Conversion.TimeoutParser, warn: false
  alias Enviable.Value

  atom_exhaustion =
    "[Preventing atom exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)"

  atom_options = """
  ### Options

  #{Schema.docs(:atom)}
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

  #{Schema.docs(:boolean)}
  """
  @typedoc since: "1.0.0"
  @type convert_boolean :: :boolean

  @typedoc """
  Indicates a conversion to `t:integer/0`.

  ### Options

  #{Schema.docs(:integer)}
  """
  @typedoc since: "1.0.0"
  @type convert_integer :: :integer

  @typedoc """
  Indicates a conversion to `t:charlist/0`.

  ### Options

  #{Schema.docs(:charlist)}
  """
  @typedoc since: "1.1.0"
  @type convert_charlist :: :charlist

  @typedoc """
  Indicates a conversion to `t:Decimal.t/0`.

  ### Options

  #{if(Code.ensure_loaded?(Decimal), do: Schema.docs(:decimal), else: "Requires the optional `:decimal` dependency.")}
  """
  @typedoc since: "1.6.0"
  @type convert_decimal :: :decimal

  @typedoc """
  Indicates a conversion to `t:float/0`.

  ### Options

  #{Schema.docs(:float)}
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

  #{Schema.docs(:json)}
  """
  @typedoc since: "1.1.0"
  @type convert_json :: :json

  @typedoc """
  Indicates a conversion to log level `t:atom/0` for `Logger.configure/1`.

  This conversion is always case-insensitive, and the result is one of `:emergency`,
  `:alert`, `:critical`, `:error`, `:warning`, `:notice`, `:info`, `:debug`, `:all`, or
  `:none`.

  ### Options

  #{Schema.docs(:log_level)}
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

  #{Schema.docs(:module)}
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
  Indicates a conversion to `t:Duration.t/0` from an ISO 8601 duration string (see
  `Duration.from_iso8601/1`).

  ### Options

  #{Schema.docs(:duration)}
  """
  @typedoc since: "2.2.0"
  @type convert_duration :: :duration

  @typedoc """
  Indicates a conversion to `t:timeout/0`.

  ### Timeout Values

  Timeout values are either ISO8601 duration strings (like `PT30M` for a 30 minute
  duration, see `Duration.from_iso8601/1`), the word `infinity`, or a non-negative integer
  value with optional suffixes. The integer part may have underscores (`_`) separating
  digits like Elixir itself.

  If no suffix is present, the value is in milliseconds. Supported suffixes are:

  - `week`, `weeks`, `w`: the number of weeks (always 7 days)
  - `day`, `days`, `d`: the number of days (always 24 hours)
  - `hour`, `hours`, `h`: the number of hours (always 60 minutes)
  - `minute`, `minutes`, `m`: the number of minutes (always 60 seconds)
  - `second`, `seconds`, `s`: the number of seconds (always 1000 milliseconds)
  - `millisecond`, `milliseconds`, `ms`: the number of milliseconds

  Suffixes may be present with or without a space (`30s` and `30 s` are the same value),
  and multiple timeouts may be chained (`1h 30m`), but may not be duplicated. Only
  lowercase suffixes are supported.

  See `Kernel.to_timeout/1` for more details.

  ### Options

  #{Schema.docs(:timeout)}
  """
  @typedoc since: "1.7.0"
  @type convert_timeout :: :timeout

  @typedoc """
  Supported default values for timeout conversions: a timeout string, a `t:timeout/0`,
  a `t:Duration.t/0`, or a keyword list as accepted by `Kernel.to_timeout/1`.
  """
  @typedoc since: "1.7.0"
  @type timeout_default ::
          String.t()
          | timeout()
          | Duration.t()
          | [{timeout_unit(), non_neg_integer()}]

  @typedoc """
  Units for keyword list timeout values, as accepted by `Kernel.to_timeout/1`.
  """
  @typedoc since: "3.0.0"
  @type timeout_unit :: :week | :day | :hour | :minute | :second | :millisecond

  @typedoc """
  Indicates a conversion from a PEM string through `:public_key.pem_decode/1`.

  ### Options

  #{Schema.docs(:pem)}
  """
  @typedoc since: "1.1.0"
  @type convert_pem :: :pem

  @typedoc """
  Possible return types for `t:convert_pem/0` conversions.

  The return types are variant on the conversion `:filter` option value:

  - `true`: either an unencrypted primary key `t:binary/0` or a list of unencrypted
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
  > `:erl_parse.parse_term/1`) Erlang code from environment variables in the context of
  > your application. Do not use this with untrusted input.

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

  @typedoc """
  Indicates no conversion: the value is returned unchanged.

  This is the conversion used for the decoded value of an encoded conversion without
  a secondary type (`:base64` is the same as `{:base64, :string}`) and for list entries
  without a secondary type (`:list` is the same as `{:list, :string}`).

  A value read from the environment or from a list entry is a `t:String.t/0`. A value
  decoded by a base encoding is a `t:binary/0`, which may not be valid UTF-8.

  ### Options

  #{Schema.docs(:string)}
  """
  @typedoc since: "3.0.0"
  @type convert_string :: :string

  @typedoc """
  All supported primitive conversions.
  """
  @typedoc since: "1.1.0"
  @type primitive ::
          convert_atom
          | convert_boolean
          | convert_charlist
          | convert_decimal
          | convert_duration
          | convert_elixir
          | convert_erlang
          | convert_float
          | convert_integer
          | convert_json
          | convert_log_level
          | convert_module
          | convert_pem
          | convert_safe_atom
          | convert_safe_module
          | convert_string
          | convert_timeout

  @typedoc """
  Decodes the value from a base 16 encoded string.

  If a secondary type is provided, a further conversion pass is made using the secondary
  type.

  ### Options

  #{Schema.docs(:base16)}

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_base16 :: :base16 | {:base16, primitive}

  @typedoc """
  Decodes the value from a base 32 encoded string.

  If a secondary type is provided, a further conversion pass is made using the secondary
  type.

  ### Options

  #{Schema.docs(:base32)}

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_base32 :: :base32 | {:base32, primitive}

  @typedoc """
  Decodes the value from a base 32 hex encoded string with extended hexadecimal alphabet.

  If a secondary type is provided, a further conversion pass is made using the secondary
  type.

  ### Options

  #{Schema.docs(:hex32)}

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_hex32 :: :hex32 | {:hex32, primitive}

  @typedoc """
  Decodes the value from a base 64 encoded string.

  If a secondary type is provided, a further conversion pass is made using the secondary
  type.

  ### Options

  #{Schema.docs(:base64)}

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.1.0"
  @type encoded_base64 :: :base64 | :url_base64 | {:base64 | :url_base64, primitive}

  @typedoc """
  Decodes the value from a string as a delimiter-separated list.

  If a secondary type is provided, a further conversion pass is made using the secondary
  type.

  ### Options

  #{Schema.docs(:list)}

  If a secondary type is provided, the options for that type may also be provided.
  """
  @typedoc since: "1.4.0"
  @type encoded_list :: :list | {:list, primitive}

  @typedoc """
  Options for the `*_as_list` functions: `:as`, the `t:encoded_list/0` options (including
  `:default`), and options for the `:as` type.
  """
  @typedoc since: "1.4.0"
  @type as_list_opt :: unquote(Schema.option_typespec(:list, as: :list))

  @typedoc """
  All supported encoded conversions.
  """
  @typedoc since: "1.1.0"
  @type encoded :: encoded_base16 | encoded_base32 | encoded_hex32 | encoded_base64 | encoded_list

  @typedoc """
  All supported conversions.
  """
  @typedoc since: "1.1.0"
  @type conversion :: primitive | encoded

  @primitives Schema.primitives()
  @encodings Schema.encodings()
  @unlisted Schema.unlisted()

  @spec convert_as(Value.t(), conversion, keyword) :: nil | term()
  @doc false
  def convert_as(%Value{} = value, type, options) do
    if !Keyword.keyword?(options) do
      option_error!(value, type, nil, "options must be a keyword list")
    end

    case normalize_type!(type) do
      {:list, inner_type} -> convert_list(value, type, inner_type, options)
      {encoding, inner_type} -> convert_encoded(value, type, encoding, inner_type, options)
      primitive -> convert_primitive(value, type, primitive, options)
    end
  end

  defp normalize_type!(type) when type in @primitives, do: type
  defp normalize_type!(type) when type in @encodings, do: {type, :string}

  if :decimal not in Schema.primitives() do
    defp normalize_type!(:decimal), do: unsupported!(:decimal, "requires the optional `:decimal` dependency")

    defp normalize_type!({encoding, :decimal}) when encoding in @encodings,
      do: unsupported!({encoding, :decimal}, "requires the optional `:decimal` dependency")
  end

  defp normalize_type!({:list, inner_type}) when inner_type in @unlisted,
    do: unsupported!({:list, inner_type}, "`#{inspect(inner_type)}` values cannot be list elements")

  defp normalize_type!({encoding, inner_type} = type) when encoding in @encodings and inner_type in @primitives,
    do: type

  defp normalize_type!({encoding, inner_type} = type)
       when encoding in @encodings and (inner_type in @encodings or is_tuple(inner_type)),
       do: unsupported!(type, "encoded conversions cannot be nested")

  defp normalize_type!(type), do: unsupported!(type, "unknown conversion type")

  defp unsupported!(type, reason) do
    raise Enviable.UnsupportedConversionError, type: type, reason: reason
  end

  defp convert_primitive(value, requested, type, options) do
    options
    |> parse!(value, requested, type)
    |> convert_value(value, type)
  end

  defp convert_encoded(value, requested, encoding, inner_type, options) do
    {_default, outer_config, inner_config} = parse_compound_opts(value, requested, encoding, inner_type, options)

    decoded = convert_value(outer_config, value, encoding)
    convert_value(inner_config, %{value | value: decoded}, inner_type)
  end

  defp convert_list(value, requested, inner_type, options) do
    {default, outer_config, inner_config} = parse_compound_opts(value, requested, :list, inner_type, options)

    default = list_default(value, requested, inner_type, inner_config, default)

    case {value, default} do
      {%Value{value: nil}, :none} ->
        nil

      {%Value{value: nil}, {:final, list}} ->
        list

      {%Value{value: nil}, {:string, string}} ->
        split_list(%{value | value: string, source: :default}, inner_type, outer_config, inner_config)

      {%Value{value: nil}, {:strings, list}} ->
        convert_elements(%{value | source: :default}, list, inner_type, inner_config)

      {value, _default} ->
        split_list(value, inner_type, outer_config, inner_config)
    end
  end

  defp parse_compound_opts(value, requested, encoding, inner_type, options) do
    {default, options} = split_option(options, :default)
    {or_raise, options} = split_option(options, :or_raise)

    check_or_raise!(value, requested, default, or_raise)
    {outer_opts, inner_opts} = split!(value, requested, encoding, inner_type, options)

    # List conversions keep the default; encoded conversions push the default to the inner
    # type.
    {outer_opts, inner_opts} =
      if encoding == :list do
        {put_default_opt(outer_opts, default), inner_opts}
      else
        {outer_opts, put_default_opt(inner_opts, default)}
      end

    outer_config = parse!(outer_opts, value, requested, encoding)
    inner_config = parse!(inner_opts, value, requested, inner_type)

    {default, outer_config, inner_config}
  end

  defp put_default_opt(opts, :none), do: opts
  defp put_default_opt(opts, {:some, value}), do: [{:default, value} | opts]

  defp check_or_raise!(value, requested, {:some, _}, {:some, _}) do
    option_error!(value, requested, [:default, :or_raise], "`:default` and `:or_raise` cannot both be provided")
  end

  defp check_or_raise!(%Value{value: nil}, _requested, _default, {:some, message}) do
    raise message
  end

  defp check_or_raise!(_value, _requested, _default, _or_raise), do: :ok

  defp split_option(options, key) do
    case Keyword.fetch(options, key) do
      {:ok, value} -> {{:some, value}, Keyword.delete(options, key)}
      :error -> {:none, options}
    end
  end

  # - a string is split and converted as if it were the value
  # - a list of strings is converted element by element as if each were a list entry
  # - any other list is prepared element by element as defaults for the element type
  defp list_default(_value, _requested, _inner, _inner_config, :none), do: :none

  defp list_default(_value, _requested, _inner, _inner_config, {:some, default}) when is_binary(default),
    do: {:string, default}

  defp list_default(value, requested, inner_type, inner_config, {:some, default}) do
    cond do
      Enum.all?(default, &is_binary/1) ->
        {:strings, default}

      Enum.any?(default, &is_binary/1) ->
        option_error!(value, requested, :default, "a list `:default` must contain only strings or no strings")

      true ->
        prepared =
          default
          |> Enum.with_index()
          |> Enum.map(fn {item, index} ->
            prepare_default_element!(value, requested, inner_type, inner_config, item, index)
          end)

        {:final, prepared}
    end
  end

  defp prepare_default_element!(value, requested, inner_type, inner_config, item, index) do
    case Config.prepare_default(inner_type, item, inner_config) do
      {:ok, prepared} ->
        prepared

      {:error, key, reason} ->
        option_error!(%{value | source: :default, index: index}, requested, key, reason)
    end
  end

  defp split_list(%Value{} = value, inner_type, list_config, inner_config) do
    elements =
      value
      |> Value.__unwrap__()
      |> String.split(list_config.delimiter, list_config.split_opts)

    convert_elements(value, elements, inner_type, inner_config)
  end

  defp convert_elements(value, elements, inner_type, inner_config) do
    elements
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      convert_value(inner_config, %{value | value: item, index: index}, inner_type)
    end)
  end

  # Routes options to the outer (encoding) and inner_type (primitive) layers. `:default` and
  # `:or_raise` are popped before this and handled at the encoded/list level, so the
  # remaining layers' keys are disjoint; anything else is unknown.
  defp split!(value, requested, outer, inner_type, options) do
    outer_keys = Schema.keys(outer) -- [:or_raise]
    inner_keys = Schema.keys(inner_type) -- [:default, :or_raise]

    {outer_opts, rest} = Keyword.split(options, outer_keys)
    {inner_opts, unknown} = Keyword.split(rest, inner_keys)

    if unknown == [] do
      {outer_opts, inner_opts}
    else
      unknown_keys =
        unknown
        |> Keyword.keys()
        |> Enum.uniq()

      supported = Enum.uniq(outer_keys ++ inner_keys ++ [:or_raise])
      option_error!(value, requested, unknown_keys, Schema.unknown_reason(unknown_keys, supported))
    end
  end

  defp parse!(options, value, requested, type) do
    case Config.parse(type, options) do
      {:ok, config} -> config
      {:error, key, reason} -> option_error!(value, requested, key, reason)
    end
  end

  defp option_error!(%Value{} = value, requested, key, reason) do
    raise Enviable.OptionError,
      env: value.name,
      source: value.source,
      index: value.index,
      type: requested,
      key: key,
      reason: reason
  end

  defp convert_value(config, %Value{value: nil}, type) do
    case config do
      %{or_raise: message} -> raise message
      _ -> apply_boolean_map(Map.get(config, :default), type, config)
    end
  end

  defp convert_value(config, %Value{} = value, type) do
    raw = Value.__unwrap__(value)

    case convert_to(type, casefold(raw, config[:casefold]), config) do
      {:ok, result} ->
        apply_boolean_map(result, type, config)

      :error ->
        raise Enviable.ConversionError, env: value.name, type: type, source: value.source, index: value.index
    end
  end

  # Boolean `:then`/`:else` mapping is applied after the boolean is resolved (converted
  # value or default). Non-boolean types and booleans without a `:map` are unchanged.
  defp apply_boolean_map(result, :boolean, %{map: {then_value, else_value}}) do
    if result, do: then_value, else: else_value
  end

  defp apply_boolean_map(result, _type, _config), do: result

  defguardp is_json(value)
            when is_binary(value) or is_boolean(value) or is_list(value) or is_map(value) or is_nil(value) or
                   is_number(value)

  @spec convert_to(conversion, nil | binary(), map()) :: {:ok, nil | term()} | :error
  defp convert_to(type, value, %{allowed: allowed})
       when type in [:atom, :module, :safe_atom, :safe_module] and is_map(allowed) do
    Map.fetch(allowed, value)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp convert_to(:atom, value, _config) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
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

  # sobelow_skip ["DOS.ModuleConcat"]
  defp convert_to(:module, value, _config) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
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

  defp convert_to(:string, value, _config), do: {:ok, value}

  defp convert_to(:safe_atom, value, _config) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  defp convert_to(:safe_module, value, _config) do
    {:ok, Module.safe_concat([value])}
  rescue
    ArgumentError -> :error
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

  # sobelow_skip ["RCE.CodeModule"]
  defp convert_to(:elixir, value, _config) do
    case Code.string_to_quoted(value) do
      {:ok, quoted} ->
        {term, _binding} = Code.eval_quoted(quoted)
        {:ok, term}

      _ ->
        :error
    end
  end

  defp convert_to(:duration, value, _config) do
    case Duration.from_iso8601(value) do
      {:ok, value} -> {:ok, value}
      _ -> :error
    end
  end

  defp convert_to(:timeout, value, _config) when is_binary(value) do
    case Duration.from_iso8601(value) do
      {:ok, value} ->
        {:ok, to_timeout(value)}

      _ ->
        case TimeoutParser.parse(value) do
          {:ok, value} -> {:ok, to_timeout(value)}
          _ -> :error
        end
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

  defp casefold(value, nil), do: value
  defp casefold(value, {_foldtype, false}), do: value
  defp casefold(value, {:upcase, type}), do: String.upcase(value, type)
  defp casefold(value, {:downcase, type}), do: String.downcase(value, type)
end
