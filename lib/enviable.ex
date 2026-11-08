defmodule Enviable do
  @moduledoc """
  Enviable is a collection of functions to improve Elixir project configuration via
  environment variables as proposed under the [12-factor][12f] application model. It works
  well with configuration environment loaders like [Dotenvy][Dotenvy] or [Nvir][nvir] and
  provides robust value conversion like [jetenv][jetenv].

  Enviable and `Enviable.Codex` are alternative interfaces for the same purpose. They are
  not interoperable. Use one or the other, not both in the same module.

  ### Usage

  Enviable will typically be imported in `config/runtime.exs` after `Config`, but may be
  used anywhere that environment variables are read.

  ```elixir
  # config/runtime.exs
  import Config
  import Enviable

  client = fetch_env!("CLIENT")
  Dotenvy.source([".env", ".env.\#{client}", get_env()], side_effect: &put_env/1)

  # Before
  #
  # config :my_app,
  #   key: System.fetch_env!("SECRET_KEY"),
  #   port: System.fetch_env!("PORT") |> String.to_integer(),
  #   ssl: System.get_env("SSL_ENABLED") in ~w[1 true]

  # After
  config :my_app,
    key: fetch_env!("SECRET_KEY"),
    port: fetch_env_as_integer!("PORT"),
    ssl: get_env_as_boolean("SSL_ENABLED")
  ```

  > #### Info {: .info}
  >
  > When using Dotenvy, the use of a `side_effect` that calls `System.put_env/1` is
  > **required**, as Enviable works with the system environment variable table. Future
  > versions of Enviable may offer ways to work with the default Dotenvy behaviour.

  ### Configuration

  Enviable has three compile-time options.

  - `:boolean_downcase`: Sets the default value for case-folding boolean conversions. Can
    be set to `:default`, `:ascii`, `:greek`, or `:turkic`. The boolean value `true` will
    be treated as `:default`.

    ```elixir
    config :enviable, :boolean_downcase, true
    config :enviable, :boolean_downcase, :default
    config :enviable, :boolean_downcase, :ascii
    ```

    If unspecified, the value is `:default`.

  - `:json_engine`: The default JSON engine to use for JSON conversions. This may be
    provided as a `t:module/0` (which must export `decode/1`) or a `t:mfa/0` tuple. When
    provided with a `t:mfa/0`, the variable value will be passed as the first parameter.

    If the engine produces `{:ok, json_value}` or an expected JSON type result, it will be
    considered successful. Any other result will be treated as failure.

    The default JSON engine is `JSON` if Elixir's `m:JSON` is available, `:json` if the
    Erlang/OTP `m::json` module is available (Erlang/OTP 27+) or provided by
    [json_polyfill][jp]. Otherwise, [Jason][jason] is the default engine.

    ```elixir
    config :enviable, :json_engine, :thoas
    config :enviable, :json_engine, {Jason, :decode, [[floats: :decimals]]}
    ```

  - `:paranoid`: Whether retrieved environment variables are wrapped in a closure for all
    functions when using Enviable.Codex. This defaults to `false`, which means that only
    the `once` family of functions secures the returned value.

    ```elixir
    config :enviable, :paranoid, true
    ```

  [12f]: https://12factor.net/
  [dotenvy]: https://hexdocs.pm/dotenvy/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [jetenv]: https://hexdocs.pm/jetenv/readme.html
  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [nvir]: https://hexdocs.pm/nvir/readme.html
  """

  alias Enviable.Codex
  alias Enviable.Conversion
  alias Enviable.Conversion.Schema
  alias Enviable.Value

  @doc """
  Set an environment variable `t:Value.t/0` only if it is not yet set.

  This is a safe wrapper around `get_env/2` piped into `put_env/1`: the current
  environment value (if any) wins over the `t:Value.t/0`'s inner value, which is used
  only as the default. If the resolved value is `nil`, the variable is erased.

  See `Enviable.Codex.put_env_new/1`.

  ### Examples

  ```elixir
  iex> Enviable.put_env_new(%Enviable.Value{name: "PORT", value: "3000"})
  :ok
  iex> Enviable.get_env("PORT")
  "3000"
  iex> Enviable.put_env_new(%Enviable.Value{name: "PORT", value: "5000"})
  :ok
  iex> Enviable.get_env("PORT")
  "3000"
  ```
  """
  @doc group: "Env"
  @spec put_env_new(Value.t()) :: :ok
  defdelegate put_env_new(value), to: Codex

  @doc """
  Set an environment variable value only if it is not yet set. This is a convenience
  wrapper around `System.put_env/2` and `System.get_env/2`.

  See `Enviable.Codex.put_env_new/2`.

  ### Examples

  ```elixir
  iex> Enviable.put_env_new("PORT", "3000")
  :ok
  iex> Enviable.get_env("PORT")
  "3000"
  iex> Enviable.put_env_new("PORT", "5000")
  :ok
  iex> Enviable.get_env("PORT")
  "3000"
  ```
  """
  @doc group: "Env"
  @spec put_env_new(String.t(), String.t() | Value.t()) :: :ok
  defdelegate put_env_new(name, value), to: Codex

  @doc """
  Returns the value of an environment variable converted to the target `type` or a default
  value if the variable is unset. If no `default` is provided, `nil` is returned (unless
  converting to `:boolean`, which will return `false`).

  Supported primitive conversions are:

  - `:atom` (`t:Enviable.Conversion.convert_atom/0`, `get_env_as_atom/2`)

  - `:boolean` (`t:Enviable.Conversion.convert_boolean/0`, `get_env_as_boolean/2`)

  - `:charlist` (`t:Enviable.Conversion.convert_charlist/0`, `get_env_as_charlist/2`)

  - `:decimal` (`t:Enviable.Conversion.convert_decimal/0`, `get_env_as_decimal/2`)

  - `:duration` (`t:Enviable.Conversion.convert_duration/0`, `get_env_as_duration/2`)

  - `:elixir` (`t:Enviable.Conversion.convert_elixir/0`, `get_env_as_elixir/1`)

  - `:erlang` (`t:Enviable.Conversion.convert_erlang/0`, `get_env_as_erlang/1`)

  - `:float` (`t:Enviable.Conversion.convert_float/0`, `get_env_as_float/2`)

  - `:integer` (`t:Enviable.Conversion.convert_integer/0`, `get_env_as_integer/2`)

  - `:json` (`t:Enviable.Conversion.convert_json/0`, `get_env_as_json/2`)

  - `:log_level` (`t:Enviable.Conversion.convert_log_level/0`, `get_env_as_log_level/2`)

  - `:module` (`t:Enviable.Conversion.convert_module/0`, `get_env_as_module/2`)

  - `:pem` (`t:Enviable.Conversion.convert_pem/0`, `get_env_as_pem/2`)

  - `:safe_atom` (`t:Enviable.Conversion.convert_safe_atom/0`, `get_env_as_safe_atom/2`)

  - `:safe_module` (`t:Enviable.Conversion.convert_safe_module/0`,
    `get_env_as_safe_module/2`)

  - `:string` (`t:Enviable.Conversion.convert_string/0`)

  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `get_env_as_timeout/2`)

  Supported encoded conversions are:

  - `:base16` (`t:Enviable.Conversion.encoded_base16/0`, `get_env_as_base16/2`)

  - `:base32` (`t:Enviable.Conversion.encoded_base32/0`, `get_env_as_base32/2`)

  - `:base64`, `:url_base64` (`t:Enviable.Conversion.encoded_base64/0`,
    `get_env_as_base64/2`, `get_env_as_url_base64/2`)

  - `:hex32` (`t:Enviable.Conversion.encoded_hex32/0`, `get_env_as_hex32/2`)

  - `:list` (`t:Enviable.Conversion.encoded_list/0`, `get_env_as_list/2`)

  See `Enviable.Conversion` for supported type conversions and options.

  ### Value Conversion and Default Values

  Value conversion will be applied only to values contained in the requested environment
  variable. Default values are used only when the environment variable is unset. There is
  a meaningful difference between an unset environment variable (where `System.get_env/1`
  will return `nil`) and an empty environment variable (where `System.get_env/1` returns
  `""`).

  ```console
  $ FOO= elixir -e 'IO.inspect([foo: System.get_env("FOO"), bar: System.get_env("BAR")])'
  [foo: "", bar: nil]
  ```

  ### Examples

  ```elixir
  iex> get_env_as("UNSET", :atom)
  nil

  iex> get_env_as("UNSET", :float)
  nil

  iex> get_env_as("UNSET", :base16)
  nil

  iex> put_env("NAME", "get_env_as")
  iex> get_env_as("NAME", :atom)
  :get_env_as

  iex> put_env("NAME", "GET_ENV_AS")
  iex> get_env_as("NAME", :safe_atom, downcase: true)
  :get_env_as

  iex> get_env_as("FLOAT", :float, default: "3.5")
  3.5

  iex> get_env_as("FLOAT", :float, default: 3.5)
  3.5

  iex> put_env("FLOAT", "3")
  iex> get_env_as("FLOAT", :float)
  3.0

  iex> put_env("FLOAT", "3.1")
  iex> get_env_as("FLOAT", :float)
  3.1

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env_as("NAME", :base16, case: :lower)
  "RED"
  iex> get_env_as("NAME", {:base16, :string}, case: :lower)
  "RED"
  iex> get_env_as("NAME", {:base16, :atom}, case: :lower, downcase: true)
  :red

  iex> put_env("LIST", "1,2,3")
  iex> get_env_as("LIST", :list)
  ["1", "2", "3"]
  iex> get_env_as("LIST", {:list, :integer})
  [1, 2, 3]

  iex> put_env("LIST", "1;2;3")
  iex> get_env_as("LIST", :list, delimiter: ";")
  ["1", "2", "3"]
  iex> get_env_as("LIST", {:list, :integer}, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "1.1.0"
  @doc group: "Conversion"
  @spec get_env_as(String.t(), Conversion.conversion(), keyword()) :: nil | term()
  def get_env_as(varname, type, opts \\ []) when is_list(opts) do
    varname
    |> Codex.get_env()
    |> Conversion.convert_as(type, opts)
  end

  atom_exhaustion =
    "[Preventing atom exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)"

  atom_options = """
  ### Options

  #{Schema.docs(:atom)}

  The `default` may be passed _either_ as a `t:atom/0` value, _or_ in options as
  `default: value` — not both.
  """

  @doc """
  Returns the value of an environment variable converted to `t:atom/0` or a default value
  if the variable is unset. If no `default` is provided, `nil` is returned.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_atom/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> get_env_as_atom("UNSET")
  nil

  iex> get_env_as_atom("UNSET", :default)
  :default

  iex> get_env_as_atom("UNSET", default: :default)
  :default

  iex> put_env("NAME", "get_env_as_atom")
  iex> get_env_as_atom("NAME")
  :get_env_as_atom
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_atom(
          String.t(),
          atom() | String.t() | [unquote(Schema.option_typespec(:atom))]
        ) :: nil | atom()
  def get_env_as_atom(varname, opts \\ [])

  def get_env_as_atom(varname, default) when is_atom(default) or is_binary(default),
    do: get_env_as(varname, :atom, default: default)

  def get_env_as_atom(varname, opts), do: get_env_as(varname, :atom, opts)

  @doc """
  Returns the value of an environment variable converted to an existing `t:atom/0` or
  a default value if the variable is unset. If no `default` is provided, `nil` is
  returned.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_existing_atom/1` which will result in an
  > exception if the resulting atom is not already known and if used without the
  > `:allowed` option. See #{atom_exhaustion} from the Security Working Group of the
  > Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> get_env_as_safe_atom("UNSET")
  nil

  iex> get_env_as_safe_atom("UNSET", :default)
  :default

  iex> get_env_as_safe_atom("UNSET", default: :default)
  :default

  iex> put_env("NAME", "GET_ENV_AS_SAFE_ATOM")
  iex> get_env_as_safe_atom("NAME", downcase: true)
  :get_env_as_safe_atom
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_safe_atom(
          String.t(),
          atom() | String.t() | [unquote(Schema.option_typespec(:safe_atom))]
        ) :: nil | atom()
  def get_env_as_safe_atom(varname, opts \\ [])

  def get_env_as_safe_atom(varname, default) when is_atom(default) or is_binary(default),
    do: get_env_as(varname, :safe_atom, default: default)

  def get_env_as_safe_atom(varname, opts), do: get_env_as(varname, :safe_atom, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value, or
  a default value if the variable is unset. If no `default` is provided, `false` will be
  returned.

  This function will always result in a `t:boolean/0` value. Unless configured with
  `truthy` or `falsy`, only the values `"1"` and `"true"` will be converted to `true` and
  any other value will result in `false`.

  ### Options

  #{Schema.docs(:boolean)}

  The `default` may be passed _either_ as a `t:boolean/0` value, _or_ in options as
  `default: value` — not both.

  ### Examples

  ```elixir
  iex> get_env_as_boolean("FLAG")
  false

  iex> get_env_as_boolean("FLAG", true)
  true

  iex> get_env_as_boolean("FLAG", default: true)
  true

  iex> put_env("FLAG", "1")
  iex> get_env_as_boolean("FLAG")
  true

  iex> put_env("FLAG", "something")
  iex> get_env_as_boolean("FLAG")
  false

  iex> put_env("FLAG", "oui")
  iex> get_env_as_boolean("FLAG", truthy: ["oui"])
  true

  iex> put_env("FLAG", "OUI")
  iex> get_env_as_boolean("FLAG", truthy: ["oui"])
  true
  iex> get_env_as_boolean("FLAG", truthy: ["oui"], downcase: false)
  false

  iex> put_env("FLAG", "NON")
  iex> get_env_as_boolean("FLAG", falsy: ["non"])
  false
  iex> get_env_as_boolean("FLAG", falsy: ["non"], downcase: false)
  true

  iex> get_env_as_boolean("FLAG", default: nil)
  ** (Enviable.OptionError) could not convert environment variable "FLAG" to type boolean: invalid `:default` value (expected boolean)

  iex> get_env_as_boolean("FLAG", downcase: nil)
  ** (Enviable.OptionError) could not convert environment variable "FLAG" to type boolean: invalid `:downcase` value (expected boolean or one of :default, :ascii, :greek, :turkic)

  iex> get_env_as_boolean("FLAG", truthy: ["oui"], falsy: ["non"])
  ** (Enviable.OptionError) could not convert environment variable "FLAG" to type boolean: `:truthy` and `:falsy` cannot both be provided

  iex> put_env("ECTO_IPV6", "true")
  iex> get_env_as_boolean("ECTO_IPV6", then: [:inet6], else: [])
  [:inet6]
  iex> get_env_as_boolean("UNSET", then: [:inet6], else: [])
  []
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_boolean(
          String.t(),
          boolean() | [unquote(Schema.option_typespec(:boolean))]
        ) :: boolean() | term()
  def get_env_as_boolean(varname, opts \\ [])
  def get_env_as_boolean(varname, default) when is_boolean(default), do: get_env_as(varname, :boolean, default: default)
  def get_env_as_boolean(varname, opts), do: get_env_as(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:charlist/0` or a default
  value if the variable is unset. If no `default` is provided, `nil` is returned.

  ### Options

  #{Schema.docs(:charlist)}

  The `default` may be passed _either_ as a `t:binary/0` or `t:charlist/0` value, _or_ in
  options as `default: value` — not both.

  ### Examples

  ```elixir
  iex> get_env_as_charlist("UNDEFINED")
  nil

  iex> get_env_as_charlist("UNDEFINED", "default")
  ~c"default"

  iex> get_env_as_charlist("UNDEFINED", ~c"default")
  ~c"default"

  iex> get_env_as_charlist("UNDEFINED", default: "default")
  ~c"default"

  iex> get_env_as_charlist("UNDEFINED", default: ~c"default")
  ~c"default"

  iex> put_env("NAME", "get_env_as")
  iex> get_env_as_charlist("NAME")
  ~c"get_env_as"
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_charlist(
          String.t(),
          String.t() | charlist | [unquote(Schema.option_typespec(:charlist))]
        ) :: nil | charlist()
  def get_env_as_charlist(varname, opts \\ [])

  def get_env_as_charlist(varname, default) when is_binary(default) do
    get_env_as(varname, :charlist, default: default)
  end

  def get_env_as_charlist(varname, opts) do
    if is_list(opts) and Keyword.keyword?(opts) do
      get_env_as(varname, :charlist, opts)
    else
      get_env_as(varname, :charlist, default: opts)
    end
  end

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value or
  a default value if the variable is unset. If no `default` is provided, `nil` is
  returned.

  ### Options

  #{Schema.docs(:integer)}

  The `default` may be passed _either_ as a `t:integer/0` or `t:binary/0` value, _or_ in
  options as `default: value` — not both.

  Failure to parse a binary string `default` or the value of the environment variable will
  result in an exception.

  ### Examples

  ```elixir
  iex> get_env_as_integer("PORT")
  nil

  iex> get_env_as_integer("PORT", 5432)
  5432

  iex> get_env_as_integer("PORT", "5432")
  5432

  iex> get_env_as_integer("PORT", default: 5432)
  5432

  iex> get_env_as_integer("PORT", default: "5432")
  5432

  iex> get_env_as_integer("PORT", default: 3.5)
  ** (Enviable.OptionError) could not convert environment variable "PORT" to type integer: invalid `:default` value (expected integer or string)

  iex> put_env("PORT", "5432")
  iex> get_env_as_integer("PORT")
  5432

  iex> put_env("PORT", "18eb")
  iex> get_env_as_integer("PORT")
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> put_env("PORT", "18EB")
  iex> get_env_as_integer("PORT", base: 16)
  6379
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_integer(
          String.t(),
          integer() | String.t() | [unquote(Schema.option_typespec(:integer))]
        ) :: nil | integer()
  def get_env_as_integer(varname, opts \\ [])

  def get_env_as_integer(varname, default) when is_binary(default) or is_integer(default),
    do: get_env_as(varname, :integer, default: default)

  def get_env_as_integer(varname, opts), do: get_env_as(varname, :integer, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:float/0` value or
  a default value if the variable is unset. If no `default` is provided, `nil` will be
  returned.

  ### Options

  #{Schema.docs(:float)}

  The `default` may be passed _either_ as a `t:float/0`, `t:integer/0`, or `t:binary/0`
  value, _or_ in options as `default: value` — not both.

  ### Examples

  ```elixir
  iex> get_env_as_float("FLOAT")
  nil

  iex> get_env_as_float("FLOAT", 25.5)
  25.5

  iex> get_env_as_float("FLOAT", 25)
  25.0

  iex> get_env_as_float("FLOAT", "255")
  255.0

  iex> get_env_as_float("FLOAT", default: 25.5)
  25.5

  iex> get_env_as_float("FLOAT", default: 25)
  25.0

  iex> get_env_as_float("FLOAT", default: "255")
  255.0

  iex> get_env_as_float("FLOAT", default: "3.5R")
  ** (Enviable.OptionError) could not convert environment variable "FLOAT" to type float: `:default` is not a valid float

  iex> put_env("FLOAT", "1")
  iex> get_env_as_float("FLOAT")
  1.0

  iex> put_env("FLOAT", "ff")
  iex> get_env_as_float("FLOAT")
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_float(
          String.t(),
          float() | integer() | String.t() | [unquote(Schema.option_typespec(:float))]
        ) :: nil | float()
  def get_env_as_float(varname, opts \\ [])

  def get_env_as_float(varname, default) when is_binary(default) or is_float(default) or is_integer(default),
    do: get_env_as(varname, :float, default: default)

  def get_env_as_float(varname, opts), do: get_env_as(varname, :float, opts)

  @doc """
  Returns the value of an environment variable converted to
  a `t:Enviable.Conversion.json/0` value or a default value if the variable is unset. If
  no `default` is provided, `nil` will be returned.

  ### Options

  #{Schema.docs(:json)}

  ### Examples

  ```elixir
  iex> get_env_as_json("JSON")
  nil

  iex> get_env_as_json("JSON", default: "3.5R")
  "3.5R"

  iex> put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> get_env_as_json("JSON", engine: &Jason.decode!/1)
  [%{"foo" => "bar"}]

  iex> put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> get_env_as_json("JSON")
  [%{"foo" => "bar"}]

  iex> put_env("JSON", "ff")
  iex> get_env_as_json("JSON")
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json

  iex> put_env("JSON", "ff")
  iex> get_env_as_json("JSON", engine: &Jason.decode!/1)
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_json(
          String.t(),
          [unquote(Schema.option_typespec(:json))]
        ) :: Conversion.json()
  def get_env_as_json(varname, opts \\ []) do
    get_env_as(varname, :json, opts)
  end

  module_options = """
  ### Options

  #{Schema.docs(:module)}

  The `default` may be passed _either_ as a `t:atom/0` or `t:binary/0` value, _or_ in
  options as `default: value` — not both.
  """

  @doc """
  Returns the value of an environment variable converted to `t:module/0` or a default
  value if the variable is unset. If no `default` is provided, `nil` will be returned.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.concat/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> get_env_as_module("UNSET")
  nil

  iex> get_env_as_module("UNSET", Enviable)
  Elixir.Enviable

  iex> put_env("NAME", "Enviable")
  iex> get_env_as_module("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_module(
          String.t(),
          module() | String.t() | [unquote(Schema.option_typespec(:module))]
        ) :: nil | module()
  def get_env_as_module(varname, opts \\ [])

  def get_env_as_module(varname, default) when is_binary(default) or is_atom(default),
    do: get_env_as(varname, :module, default: default)

  def get_env_as_module(varname, opts), do: get_env_as(varname, :module, opts)

  @doc """
  Returns the value of an environment variable converted to `t:module/0` or a default
  value if the variable is unset. If no `default` is provided, `nil` will be returned. The
  resulting `t:module/0` must already exist.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.safe_concat/1` which will result in an exception
  > if the resulting module is not already known and if used without the `:allowed`
  > option. See #{atom_exhaustion} from the Security Working Group of the Erlang Ecosystem
  > Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> get_env_as_safe_module("UNSET")
  nil

  iex> get_env_as_safe_module("UNSET", Enviable)
  Elixir.Enviable

  iex> put_env("NAME", "Enviable")
  iex> get_env_as_safe_module("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_safe_module(
          String.t(),
          module() | String.t() | [unquote(Schema.option_typespec(:safe_module))]
        ) :: nil | module()
  def get_env_as_safe_module(varname, opts \\ [])

  def get_env_as_safe_module(varname, default) when is_binary(default) or is_atom(default),
    do: get_env_as(varname, :safe_module, default: default)

  def get_env_as_safe_module(varname, opts), do: get_env_as(varname, :safe_module, opts)

  @doc """
  Returns the value of an environment variable converted to a log level `t:atom/0` for
  `Logger.configure/1` or a default value if the variable is unset. If no `default` is
  provided, `nil` will be returned.

  ### Options

  #{Schema.docs(:log_level)}

  The `default` may be passed _either_ as a `t:atom/0` or `t:binary/0` value, _or_ in
  options as `default: value` — not both.

  ### Examples

  ```elixir
  iex> get_env_as_log_level("LOG_LEVEL")
  nil

  iex> get_env_as_log_level("LOG_LEVEL", :error)
  :error

  iex> get_env_as_log_level("LOG_LEVEL", "info")
  :info

  iex> get_env_as_log_level("LOG_LEVEL", default: :error)
  :error

  iex> get_env_as_log_level("LOG_LEVEL", default: "info")
  :info

  iex> put_env("LOG_LEVEL", "critical")
  iex> get_env_as_log_level("LOG_LEVEL")
  :critical
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_log_level(
          String.t(),
          Conversion.log_level() | String.t() | [unquote(Schema.option_typespec(:log_level))]
        ) :: nil | Conversion.log_level()
  def get_env_as_log_level(varname, opts \\ [])

  def get_env_as_log_level(varname, default) when is_binary(default) or is_atom(default),
    do: get_env_as(varname, :log_level, default: default)

  def get_env_as_log_level(varname, opts), do: get_env_as(varname, :log_level, opts)

  @doc """
  Returns the value of an environment variable converted from a PEM string through
  `:public_key.pem_decode/1` or `nil` if the variable is unset.

  ### Options

  #{Schema.docs(:pem)}

  ### Examples

  ```elixir
  iex> get_env_as_pem("PEM")
  nil

  iex> put_env("PEM", "")
  iex> get_env_as_pem("PEM")
  []
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_pem(
          String.t(),
          [unquote(Schema.option_typespec(:pem))]
        ) :: nil | Conversion.pem()
  def get_env_as_pem(varname, opts \\ []) do
    get_env_as(varname, :pem, opts)
  end

  @doc """
  Returns the value of an environment variable parsed and evaluated as Erlang code, or
  `nil` if the environment variable is not set.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded with `{:base64, :erlang}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `:erl_scan.string/1`) and evaluates (with
  > `:erl_parse.parse_term/1`) Erlang code from environment variables in the context of
  > your application. Do not use this with untrusted input.

  ### Examples

  ```elixir
  iex> get_env_as_erlang("TERM")
  nil

  iex> put_env("TERM", "{ok, true}.")
  iex> get_env_as_erlang("TERM")
  {:ok, true}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_erlang(String.t()) :: nil | term()
  def get_env_as_erlang(varname) do
    get_env_as(varname, :erlang, [])
  end

  @doc """
  Returns the value of an environment variable parsed and evaluated as Elixir code, or
  `nil` if the environment variable is not set.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded with `{:base64, :elixir}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `Code.string_to_quoted/1`) and evaluates (with
  > `Code.eval_quoted/1`) elixir code from environment variables in the context of your
  > application. Do not use this with untrusted input.

  ### Examples

  ```elixir
  iex> get_env_as_elixir("TERM")
  nil

  iex> put_env("TERM", "11000..11100//3")
  iex> get_env_as_elixir("TERM")
  11000..11100//3
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_elixir(String.t()) :: nil | term()
  def get_env_as_elixir(varname) do
    get_env_as(varname, :elixir, [])
  end

  @doc """
  Returns the value of an environment variable decoded from a base 16 string or `nil` if
  the environment variable is not set.

  ## Options

  #{Schema.docs(:base16, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env_as_base16("NAME")
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env_as_base16("NAME", case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env_as_base16("NAME", as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env_as_base16("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_base16(
          String.t(),
          [unquote(Schema.option_typespec(:base16, as: :encoded))]
        ) :: nil | term()
  def get_env_as_base16(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base16, opts}
        {type, opts} -> {{:base16, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 string or `nil` if
  the environment variable is not set.

  ## Options

  #{Schema.docs(:base32, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env_as_base32("NAME")
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env_as_base32("NAME", case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env_as_base32("NAME", as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env_as_base32("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_base32(
          String.t(),
          [unquote(Schema.option_typespec(:base32, as: :encoded))]
        ) :: nil | term()
  def get_env_as_base32(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base32, opts}
        {type, opts} -> {{:base32, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 hex encoded string
  or `nil` if the environment variable is not set.

  ## Options

  #{Schema.docs(:hex32, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env_as_hex32("NAME")
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env_as_hex32("NAME", case: :lower)
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env_as_hex32("NAME", as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env_as_hex32("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_hex32(
          String.t(),
          [unquote(Schema.option_typespec(:hex32, as: :encoded))]
        ) :: nil | term()
  def get_env_as_hex32(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:hex32, opts}
        {type, opts} -> {{:hex32, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 64 string or `nil` if
  the environment variable is not set.

  ## Options

  #{Schema.docs(:base64, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env_as_base64("NAME")
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env_as_base64("NAME", padding: false)
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env_as_base64("NAME", as: :string, padding: true)
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env_as_base64("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_base64(
          String.t(),
          [unquote(Schema.option_typespec(:base64, as: :encoded))]
        ) :: nil | term()
  def get_env_as_base64(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base64, opts}
        {type, opts} -> {{:base64, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a URL-safe base 64 string or
  `nil` if the environment variable is not set.

  ## Options

  #{Schema.docs(:url_base64, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env_as_url_base64("NAME")
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env_as_url_base64("NAME", padding: false)
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env_as_url_base64("NAME", as: :string, padding: true)
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env_as_url_base64("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_url_base64(
          String.t(),
          [unquote(Schema.option_typespec(:url_base64, as: :encoded))]
        ) :: nil | term()
  def get_env_as_url_base64(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:url_base64, opts}
        {type, opts} -> {{:url_base64, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable parsed as a delimiter-separated list.

  ## Options

  #{Schema.docs(:list, as: :list)}

  ### Examples

  ```elixir
  iex> put_env("LIST", "1,2,3")
  iex> get_env_as_list("LIST")
  ["1", "2", "3"]
  iex> get_env_as_list("LIST", as: :integer)
  [1, 2, 3]

  iex> put_env("LIST", "1;2;3")
  iex> get_env_as_list("LIST", delimiter: ";")
  ["1", "2", "3"]
  iex> get_env_as_list("LIST", as: :integer, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_list(
          String.t(),
          [Conversion.as_list_opt()]
        ) :: nil | list()
  def get_env_as_list(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:list, opts}
        {type, opts} -> {{:list, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable converted to the target `type` as
  `{:ok, term()}` or `:error` if the variable is unset.

  Supported primitive conversions are:

  - `:atom` (`t:Enviable.Conversion.convert_atom/0`, `fetch_env_as_atom/2`)

  - `:boolean` (`t:Enviable.Conversion.convert_boolean/0`, `fetch_env_as_boolean/2`)

  - `:charlist` (`t:Enviable.Conversion.convert_charlist/0`, `fetch_env_as_charlist/1`)

  - `:decimal` (`t:Enviable.Conversion.convert_decimal/0`, `fetch_env_as_decimal/1`)

  - `:duration` (`t:Enviable.Conversion.convert_duration/0`, `fetch_env_as_duration/2`)

  - `:elixir` (`t:Enviable.Conversion.convert_elixir/0`, `fetch_env_as_elixir/1`)

  - `:erlang` (`t:Enviable.Conversion.convert_erlang/0`, `fetch_env_as_erlang/1`)

  - `:float` (`t:Enviable.Conversion.convert_float/0`, `fetch_env_as_float/1`)

  - `:integer` (`t:Enviable.Conversion.convert_integer/0`, `fetch_env_as_integer/2`)

  - `:json` (`t:Enviable.Conversion.convert_json/0`, `fetch_env_as_json/2`)

  - `:log_level` (`t:Enviable.Conversion.convert_log_level/0`, `fetch_env_as_log_level/1`)

  - `:module` (`t:Enviable.Conversion.convert_module/0`, `fetch_env_as_module/2`)

  - `:pem` (`t:Enviable.Conversion.convert_pem/0`, `fetch_env_as_pem/2`)

  - `:safe_atom` (`t:Enviable.Conversion.convert_safe_atom/0`, `fetch_env_as_safe_atom/2`)

  - `:safe_module` (`t:Enviable.Conversion.convert_safe_module/0`,
    `fetch_env_as_safe_module/2`)

  - `:string` (`t:Enviable.Conversion.convert_string/0`)

  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `fetch_env_as_timeout/1`)

  Supported encoded conversions are:

  - `:base16` (`t:Enviable.Conversion.encoded_base16/0`, `fetch_env_as_base16/2`)

  - `:base32` (`t:Enviable.Conversion.encoded_base32/0`, `fetch_env_as_base32/2`)

  - `:base64`, `:url_base64` (`t:Enviable.Conversion.encoded_base64/0`,
    `fetch_env_as_base64/2`, `fetch_env_as_url_base64/2`)
  - `:hex32` (`t:Enviable.Conversion.encoded_hex32/0`, `fetch_env_as_hex32/2`)

  - `:list` (`t:Enviable.Conversion.encoded_list/0`, `fetch_env_as_list/2`)

  See `Enviable.Conversion` for supported type conversions and options. `:default` and
  `:or_raise` options are ignored in `fetch_env_as/3` and the related `fetch_env_as_*`
  functions.

  ### Examples

  ```elixir
  iex> fetch_env_as("UNSET", :atom)
  :error

  iex> fetch_env_as("UNSET", :float)
  :error

  iex> fetch_env_as("UNSET", :base16)
  :error

  iex> put_env("NAME", "fetch_env_as")
  iex> fetch_env_as("NAME", :atom)
  {:ok, :fetch_env_as}

  iex> put_env("NAME", "FETCH_ENV_AS")
  iex> fetch_env_as("NAME", :safe_atom, downcase: true)
  {:ok, :fetch_env_as}

  iex> fetch_env_as("UNSET", :float, default: "3.5")
  :error

  iex> fetch_env_as("UNSET", :float, default: 3.5)
  :error

  iex> put_env("FLOAT", "3")
  iex> fetch_env_as("FLOAT", :float)
  {:ok, 3.0}
  iex> fetch_env_as("FLOAT", :float, default: :not_a_float)
  {:ok, 3.0}

  iex> put_env("FLOAT", "3.1")
  iex> fetch_env_as("FLOAT", :float)
  {:ok, 3.1}

  iex> red = Base.encode16("RED", case: :lower)
  iex> put_env("NAME", red)
  iex> fetch_env_as("NAME", :base16, case: :lower)
  {:ok, "RED"}
  iex> fetch_env_as("NAME", {:base16, :string}, case: :lower)
  {:ok, "RED"}
  iex> fetch_env_as("NAME", {:base16, :atom}, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.1.0"
  @doc group: "Conversion"
  @spec fetch_env_as(String.t(), Conversion.conversion(), keyword()) :: {:ok, term()} | :error
  def fetch_env_as(varname, type, opts \\ []) when is_list(opts) do
    case Codex.fetch_env(varname) do
      :error -> :error
      {:ok, value} -> {:ok, Conversion.convert_as(value, type, Keyword.drop(opts, [:default, :or_raise]))}
    end
  end

  atom_options = """
  ### Options

  #{Schema.docs(:atom, except: [:default, :or_raise])}
  """

  @doc """
  Returns the value of an environment variable converted to `t:atom/0` as `{:ok, atom()}`
  or `:error` if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_atom/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_atom("UNSET")
  :error

  iex> put_env("NAME", "fetch_env_as_atom")
  iex> fetch_env_as_atom("NAME")
  {:ok,  :fetch_env_as_atom}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_atom(
          String.t(),
          [unquote(Schema.option_typespec(:atom, except: [:default, :or_raise]))]
        ) :: {:ok, atom()} | :error
  def fetch_env_as_atom(varname, opts \\ []) do
    fetch_env_as(varname, :atom, opts)
  end

  @doc """
  Returns the value of an environment variable converted to an existing `t:atom/0` as
  `{:ok, atom()}` or `:error` if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_existing_atom/1` which will result in an
  > exception if the resulting atom is not already known and if used without the
  > `:allowed` option. See #{atom_exhaustion} from the Security Working Group of the
  > Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_safe_atom("UNSET")
  :error

  iex> put_env("NAME", "FETCH_ENV_AS_SAFE_ATOM")
  iex> fetch_env_as_safe_atom("NAME", downcase: true)
  {:ok, :fetch_env_as_safe_atom}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_atom(
          String.t(),
          [unquote(Schema.option_typespec(:safe_atom, except: [:default, :or_raise]))]
        ) :: {:ok, atom()} | :error
  def fetch_env_as_safe_atom(varname, opts \\ []) do
    fetch_env_as(varname, :safe_atom, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value as
  `{:ok, boolean()}` or `:error` if the variable is unset.

  This function will always result in a `t:boolean/0` value. Unless configured with
  `truthy` or `falsy`, only the values `"1"` and `"true"` will be converted to `true` and
  any other value will result in `false`.

  ### Options

  #{Schema.docs(:boolean, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> fetch_env_as_boolean("UNSET")
  :error

  iex> put_env("FLAG", "1")
  iex> fetch_env_as_boolean("FLAG")
  {:ok, true}

  iex> put_env("FLAG", "something")
  iex> fetch_env_as_boolean("FLAG")
  {:ok, false}

  iex> put_env("FLAG", "oui")
  iex> fetch_env_as_boolean("FLAG", truthy: ["oui"])
  {:ok, true}

  iex> put_env("FLAG", "OUI")
  iex> fetch_env_as_boolean("FLAG", truthy: ["oui"])
  {:ok, true}

  iex> put_env("FLAG", "OUI")
  iex> fetch_env_as_boolean("FLAG", truthy: ["oui"], downcase: false)
  {:ok, false}

  iex> put_env("FLAG", "NON")
  iex> fetch_env_as_boolean("FLAG", falsy: ["non"])
  {:ok, false}

  iex> put_env("FLAG", "NON")
  iex> fetch_env_as_boolean("FLAG", falsy: ["non"], downcase: false)
  {:ok, true}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_boolean(
          String.t(),
          [unquote(Schema.option_typespec(:boolean, except: [:default, :or_raise]))]
        ) :: {:ok, boolean() | term()} | :error
  def fetch_env_as_boolean(varname, opts \\ []) do
    fetch_env_as(varname, :boolean, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:charlist/0` as
  `{:ok, charlist()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_charlist("UNSET")
  :error

  iex> put_env("NAME", "fetch_env_as")
  iex> fetch_env_as_charlist("NAME")
  {:ok, ~c"fetch_env_as"}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_charlist(String.t()) :: {:ok, charlist()} | :error
  def fetch_env_as_charlist(varname) do
    fetch_env_as(varname, :charlist, [])
  end

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value as
  `{:ok, integer()}` or `:error` if the variable is unset.

  ### Options

  #{Schema.docs(:integer, except: [:default, :or_raise])}

  Failure to parse the value of the environment variable will result in an exception.

  ### Examples

  ```elixir
  iex> fetch_env_as_integer("UNSET")
  :error

  iex> put_env("PORT", "5432")
  iex> fetch_env_as_integer("PORT")
  {:ok, 5432}

  iex> put_env("PORT", "18eb")
  iex> fetch_env_as_integer("PORT")
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> put_env("PORT", "18EB")
  iex> fetch_env_as_integer("PORT", base: 16)
  {:ok, 6379}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_integer(
          String.t(),
          [unquote(Schema.option_typespec(:integer, except: [:default, :or_raise]))]
        ) :: {:ok, integer()} | :error
  def fetch_env_as_integer(varname, opts \\ []) do
    fetch_env_as(varname, :integer, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:float/0` value as
  `{:ok, float()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_float("UNSET")
  :error

  iex> put_env("FLOAT", "1")
  iex> fetch_env_as_float("FLOAT")
  {:ok, 1.0}

  iex> put_env("FLOAT", "ff")
  iex> fetch_env_as_float("FLOAT")
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_float(String.t()) :: {:ok, float()} | :error
  def fetch_env_as_float(varname) do
    fetch_env_as(varname, :float, [])
  end

  @doc """
  Returns the value of an environment variable converted to
  a `t:Enviable.Conversion.json/0` value as `{:ok, Conversion.json()}` or `:error` if the
  variable is unset.

  ### Options

  #{Schema.docs(:json, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> fetch_env_as_json("UNSET")
  :error

  iex> put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> fetch_env_as_json("JSON")
  {:ok, [%{"foo" => "bar"}]}

  iex> put_env("JSON", "ff")
  iex> fetch_env_as_json("JSON")
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_json(
          String.t(),
          [unquote(Schema.option_typespec(:json, except: [:default, :or_raise]))]
        ) :: {:ok, Conversion.json()} | :error
  def fetch_env_as_json(varname, opts \\ []) do
    fetch_env_as(varname, :json, opts)
  end

  module_options = """
  ### Options

  #{Schema.docs(:module, except: [:default, :or_raise])}
  """

  @doc """
  Returns the value of an environment variable converted to `t:module/0` as
  `{:ok, module()}` or `:error` if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.concat/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_module("UNSET")
  :error

  iex> put_env("NAME", "Enviable")
  iex> fetch_env_as_module("NAME")
  {:ok, Elixir.Enviable}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_module(
          String.t(),
          [unquote(Schema.option_typespec(:module, except: [:default, :or_raise]))]
        ) :: {:ok, module()} | :error
  def fetch_env_as_module(varname, opts \\ []) do
    fetch_env_as(varname, :module, opts)
  end

  @doc """
  Returns the value of an environment variable converted to `t:module/0` as
  `{:ok, module()}` or `:error` if the variable is unset.  The resulting `t:module/0` must
  already exist.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.safe_concat/1` which will result in an exception
  > if the resulting module is not already known and if used without the `:allowed`
  > option. See #{atom_exhaustion} from the Security Working Group of the Erlang Ecosystem
  > Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_safe_module("UNSET")
  :error

  iex> put_env("NAME", "Enviable")
  iex> fetch_env_as_safe_module("NAME")
  {:ok, Elixir.Enviable}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_module(
          String.t(),
          [unquote(Schema.option_typespec(:safe_module, except: [:default, :or_raise]))]
        ) :: {:ok, module()} | :error
  def fetch_env_as_safe_module(varname, opts \\ []) do
    fetch_env_as(varname, :safe_module, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a log level `t:atom/0` for
  `Logger.configure/1` as `{:ok, atom()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_log_level("UNSET")
  :error

  iex> put_env("LOG_LEVEL", "critical")
  iex> fetch_env_as_log_level("LOG_LEVEL")
  {:ok, :critical}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_log_level(String.t()) :: {:ok, Conversion.log_level()} | :error
  def fetch_env_as_log_level(varname) do
    fetch_env_as(varname, :log_level, [])
  end

  @doc """
  Returns the value of an environment variable converted from a PEM string through
  `:public_key.pem_decode/1` as `{:ok, value}` or `:error` if the variable is unset.

  ### Options

  #{Schema.docs(:pem, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> fetch_env_as_pem("UNSET")
  :error

  iex> put_env("PEM", "")
  iex> fetch_env_as_pem("PEM")
  {:ok, []}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_pem(
          String.t(),
          [unquote(Schema.option_typespec(:pem, except: [:or_raise]))]
        ) :: {:ok, Conversion.pem()} | :error
  def fetch_env_as_pem(varname, opts \\ []) do
    fetch_env_as(varname, :pem, opts)
  end

  @doc """
  Returns the value of an environment variable parsed and evaluated as Erlang code with
  the result as `{:ok, term()}`, or `:error` if the environment variable is not set.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded with `{:base64, :erlang}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `:erl_scan.string/1`) and evaluates (with
  > `:erl_parse.parse_term/1`) Erlang code from environment variables in the context of
  > your application. Do not use this with untrusted input.

  ### Examples

  ```elixir
  iex> fetch_env_as_erlang("UNSET")
  :error

  iex> put_env("TERM", "{ok, true}.")
  iex> fetch_env_as_erlang("TERM")
  {:ok, {:ok, true}}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_erlang(String.t()) :: {:ok, term()} | :error
  def fetch_env_as_erlang(varname) do
    fetch_env_as(varname, :erlang, [])
  end

  @doc """
  Returns the value of an environment variable parsed and evaluated as Elixir code with
  the result as `{:ok, term()}`, or `:error` if the environment variable is not set.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded with `{:base64, :elixir}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `Code.string_to_quoted/1`) and evaluates (with
  > `Code.eval_quoted/1`) elixir code from environment variables in the context of your
  > application. Do not use this with untrusted input.

  ### Examples

  ```elixir
  iex> fetch_env_as_elixir("UNSET")
  :error

  iex> put_env("TERM", "11000..11100//3")
  iex> fetch_env_as_elixir("TERM")
  {:ok, 11000..11100//3}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_elixir(String.t()) :: {:ok, term()} | :error
  def fetch_env_as_elixir(varname) do
    fetch_env_as(varname, :elixir, [])
  end

  @doc """
  Returns the value of an environment variable decoded from a base 16 string as
  `{:ok, term()}` or `:error` if the environment variable is not set.

  ## Options

  #{Schema.docs(:base16, as: :encoded, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16("NAME")
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16("NAME", case: :lower)
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16("NAME", as: :string, case: :lower)
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16("NAME", as: :atom, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base16(
          String.t(),
          [unquote(Schema.option_typespec(:base16, as: :encoded, except: [:default, :or_raise]))]
        ) :: :error | {:ok, term()}
  def fetch_env_as_base16(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base16, opts}
        {type, opts} -> {{:base16, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 string as
  `{:ok, term()}` or `:error` if the environment variable is not set.

  ## Options

  #{Schema.docs(:base32, as: :encoded, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32("NAME")
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32("NAME", case: :lower)
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32("NAME", as: :string, case: :lower)
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32("NAME", as: :atom, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base32(
          String.t(),
          [unquote(Schema.option_typespec(:base32, as: :encoded, except: [:default, :or_raise]))]
        ) :: :error | {:ok, term()}
  def fetch_env_as_base32(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base32, opts}
        {type, opts} -> {{:base32, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 hex encoded string
  as `{:ok, term()}` or `:error` if the environment variable is not set.

  ## Options

  #{Schema.docs(:hex32, as: :encoded, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32("NAME")
  {:ok, "RED"}

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32("NAME", case: :lower)
  {:ok, "RED"}

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32("NAME", as: :string, case: :lower)
  {:ok, "RED"}

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32("NAME", as: :atom, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_hex32(
          String.t(),
          [unquote(Schema.option_typespec(:hex32, as: :encoded, except: [:default, :or_raise]))]
        ) :: :error | {:ok, term()}
  def fetch_env_as_hex32(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:hex32, opts}
        {type, opts} -> {{:hex32, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 64 string as
  `{:ok, term()}` or `:error` if the environment variable is not set.

  ## Options

  #{Schema.docs(:base64, as: :encoded, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64("NAME")
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64("NAME", padding: false)
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64("NAME", as: :string, padding: true)
  {:ok, "RED"}

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64("NAME", as: :atom, downcase: true, padding: false)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base64(
          String.t(),
          [unquote(Schema.option_typespec(:base64, as: :encoded, except: [:default, :or_raise]))]
        ) :: :error | {:ok, term()}
  def fetch_env_as_base64(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base64, opts}
        {type, opts} -> {{:base64, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a URL-safe base 64 string as
  `{:ok, term()}` or `:error` if the environment variable is not set.

  ## Options

  #{Schema.docs(:url_base64, as: :encoded, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64("NAME")
  {:ok, "RED"}

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64("NAME", padding: false)
  {:ok, "RED"}

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64("NAME", as: :string, padding: true)
  {:ok, "RED"}

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64("NAME", as: :atom, downcase: true, padding: false)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_url_base64(
          String.t(),
          [unquote(Schema.option_typespec(:url_base64, as: :encoded, except: [:default, :or_raise]))]
        ) :: :error | {:ok, term()}
  def fetch_env_as_url_base64(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:url_base64, opts}
        {type, opts} -> {{:url_base64, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable parsed as a delimiter-separated list.

  ## Options

  #{Schema.docs(:list, as: :list, except: [:default, :or_raise])}

  ### Examples

  ```elixir
  iex> put_env("LIST", "1,2,3")
  iex> fetch_env_as_list("LIST")
  {:ok, ["1", "2", "3"]}
  iex> fetch_env_as_list("LIST", as: :integer)
  {:ok, [1, 2, 3]}

  iex> put_env("LIST", "1;2;3")
  iex> fetch_env_as_list("LIST", delimiter: ";")
  {:ok, ["1", "2", "3"]}
  iex> fetch_env_as_list("LIST", as: :integer, delimiter: ";")
  {:ok, [1, 2, 3]}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_list(
          String.t(),
          [unquote(Schema.option_typespec(:list, as: :list, except: [:default, :or_raise]))]
        ) :: :error | {:ok, list()}
  def fetch_env_as_list(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:list, opts}
        {type, opts} -> {{:list, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable converted to the target `type` or raises an
  exception if the variable is unset.

  Supported primitive conversions are:

  - `:atom` (`t:Enviable.Conversion.convert_atom/0`, `fetch_env_as_atom!/2`)

  - `:boolean` (`t:Enviable.Conversion.convert_boolean/0`, `fetch_env_as_boolean!/2`)

  - `:charlist` (`t:Enviable.Conversion.convert_charlist/0`, `fetch_env_as_charlist!/2`)

  - `:decimal` (`t:Enviable.Conversion.convert_decimal/0`, `fetch_env_as_decimal!/2`)

  - `:duration` (`t:Enviable.Conversion.convert_duration/0`, `fetch_env_as_duration!/2`)

  - `:elixir` (`t:Enviable.Conversion.convert_elixir/0`, `fetch_env_as_elixir!/1`)

  - `:erlang` (`t:Enviable.Conversion.convert_erlang/0`, `fetch_env_as_erlang!/1`)

  - `:float` (`t:Enviable.Conversion.convert_float/0`, `fetch_env_as_float!/2`)

  - `:integer` (`t:Enviable.Conversion.convert_integer/0`, `fetch_env_as_integer!/2`)

  - `:json` (`t:Enviable.Conversion.convert_json/0`, `fetch_env_as_json!/2`)

  - `:log_level` (`t:Enviable.Conversion.convert_log_level/0`,
    `fetch_env_as_log_level!/2`)

  - `:module` (`t:Enviable.Conversion.convert_module/0`, `fetch_env_as_module!/2`)

  - `:pem` (`t:Enviable.Conversion.convert_pem/0`, `fetch_env_as_pem!/2`)

  - `:safe_atom` (`t:Enviable.Conversion.convert_safe_atom/0`,
    `fetch_env_as_safe_atom!/2`)

  - `:safe_module` (`t:Enviable.Conversion.convert_safe_module/0`,
    `fetch_env_as_safe_module!/2`)

  - `:string` (`t:Enviable.Conversion.convert_string/0`)

  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `fetch_env_as_timeout!/2`)

  Supported encoded conversions are:

  - `:base16` (`t:Enviable.Conversion.encoded_base16/0`, `fetch_env_as_base16!/2`)

  - `:base32` (`t:Enviable.Conversion.encoded_base32/0`, `fetch_env_as_base32!/2`)

  - `:base64`, `:url_base64` (`t:Enviable.Conversion.encoded_base64/0`,
    `fetch_env_as_base64!/2`, `fetch_env_as_url_base64!/2`)
  - `:hex32` (`t:Enviable.Conversion.encoded_hex32/0`, `fetch_env_as_hex32!/2`)

  - `:list` (`t:Enviable.Conversion.encoded_list/0`, `fetch_env_as_list!/2`)

  See `Enviable.Conversion` for supported type conversions and options. The `:default`
  option is ignored in `fetch_env_as!/3` and the related `fetch_env_as_*!` functions.

  ### Examples

  ```elixir
  iex> fetch_env_as!("UNSET", :atom)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> fetch_env_as!("UNSET", :float)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> fetch_env_as!("UNSET", :base16)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("NAME", "fetch_env_as!")
  iex> fetch_env_as!("NAME", :atom)
  :fetch_env_as!

  iex> put_env("NAME", "FETCH_ENV_AS!")
  iex> fetch_env_as!("NAME", :safe_atom, downcase: true)
  :fetch_env_as!

  iex> fetch_env_as!("UNSET", :float, default: "3.5")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> fetch_env_as!("UNSET", :float, default: 3.5)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("FLOAT", "3")
  iex> fetch_env_as!("FLOAT", :float)
  3.0
  iex> fetch_env_as!("FLOAT", :float, default: :not_a_float)
  3.0

  iex> put_env("FLOAT", "3.1")
  iex> fetch_env_as!("FLOAT", :float)
  3.1

  iex> red = Base.encode16("RED", case: :lower)
  iex> put_env("NAME", red)
  iex> fetch_env_as!("NAME", :base16, case: :lower)
  "RED"
  iex> fetch_env_as!("NAME", {:base16, :string}, case: :lower)
  "RED"
  iex> fetch_env_as!("NAME", {:base16, :atom}, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.1.0"
  @doc group: "Conversion"
  @spec fetch_env_as!(String.t(), Conversion.conversion(), keyword()) :: term()
  def fetch_env_as!(varname, type, opts \\ []) when is_list(opts) do
    {fetch_opts, opts} =
      opts
      |> Keyword.delete(:default)
      |> Keyword.split([:or_raise])

    varname
    |> Codex.fetch_env!(fetch_opts)
    |> Conversion.convert_as(type, opts)
  end

  @doc """
  Returns the value of an environment variable converted to `t:atom/0` or raises an
  exception if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_atom/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_atom!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("NAME", "fetch_env_as_atom!")
  iex> fetch_env_as_atom!("NAME")
  :fetch_env_as_atom!
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_atom!(
          String.t(),
          [unquote(Schema.option_typespec(:atom, except: [:default]))]
        ) :: atom()
  def fetch_env_as_atom!(varname, opts \\ []) do
    fetch_env_as!(varname, :atom, opts)
  end

  @doc """
  Returns the value of an environment variable converted to an existing `t:atom/0` or
  raises an exception if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_existing_atom/1` which will result in an
  > exception if the resulting atom is not already known and if used without the
  > `:allowed` option. See #{atom_exhaustion} from the Security Working Group of the
  > Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_safe_atom!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("NAME", "FETCH_ENV_AS_SAFE_ATOM!")
  iex> fetch_env_as_safe_atom!("NAME", downcase: true)
  :fetch_env_as_safe_atom!
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_atom!(
          String.t(),
          [unquote(Schema.option_typespec(:safe_atom, except: [:default]))]
        ) :: atom()
  def fetch_env_as_safe_atom!(varname, opts \\ []) do
    fetch_env_as!(varname, :safe_atom, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value or
  raises an exception if the variable is unset.

  This function will always result in a `t:boolean/0` value. Unless configured with
  `truthy` or `falsy`, only the values `"1"` and `"true"` will be converted to `true` and
  any other value will result in `false`.

  ### Options

  #{Schema.docs(:boolean, except: [:default])}

  ### Examples

  ```elixir
  iex> fetch_env_as_boolean!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("FLAG", "1")
  iex> fetch_env_as_boolean!("FLAG")
  true

  iex> put_env("FLAG", "something")
  iex> fetch_env_as_boolean!("FLAG")
  false

  iex> put_env("FLAG", "oui")
  iex> fetch_env_as_boolean!("FLAG", truthy: ["oui"])
  true

  iex> put_env("FLAG", "OUI")
  iex> fetch_env_as_boolean!("FLAG", truthy: ["oui"])
  true

  iex> put_env("FLAG", "OUI")
  iex> fetch_env_as_boolean!("FLAG", truthy: ["oui"], downcase: false)
  false

  iex> put_env("FLAG", "NON")
  iex> fetch_env_as_boolean!("FLAG", falsy: ["non"])
  false

  iex> put_env("FLAG", "NON")
  iex> fetch_env_as_boolean!("FLAG", falsy: ["non"], downcase: false)
  true
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_boolean!(
          String.t(),
          [unquote(Schema.option_typespec(:boolean, except: [:default]))]
        ) :: boolean() | term()
  def fetch_env_as_boolean!(varname, opts \\ []) do
    fetch_env_as!(varname, :boolean, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:charlist/0` or raises an
  exception if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_charlist!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("NAME", "fetch_env_as")
  iex> fetch_env_as_charlist!("NAME")
  ~c"fetch_env_as"
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_charlist!(String.t()) :: charlist()
  def fetch_env_as_charlist!(varname) do
    fetch_env_as!(varname, :charlist, [])
  end

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value or
  raises an exception if the variable is unset.

  ### Options

  #{Schema.docs(:integer, except: [:default])}

  Failure to parse the value of the environment variable will result in an exception.

  ### Examples

  ```elixir
  iex> fetch_env_as_integer!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> fetch_env_as_integer!("UNSET", or_raise: "PORT must be set")
  ** (RuntimeError) PORT must be set

  iex> put_env("PORT", "5432")
  iex> fetch_env_as_integer!("PORT")
  5432

  iex> put_env("PORT", "18eb")
  iex> fetch_env_as_integer!("PORT")
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> put_env("PORT", "18EB")
  iex> fetch_env_as_integer!("PORT", base: 16)
  6379
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_integer!(
          String.t(),
          [unquote(Schema.option_typespec(:integer, except: [:default]))]
        ) :: integer()
  def fetch_env_as_integer!(varname, opts \\ []) do
    fetch_env_as!(varname, :integer, opts)
  end

  if Code.ensure_loaded?(Decimal) do
    @doc """
    Returns the value of an environment variable converted to a `t:Decimal.t/0` value or
    a default value if the variable is unset. If no `default` is provided, `nil` will be
    returned.

    ### Options

    #{Schema.docs(:decimal)}

    The `default` may be passed _either_ as a `t:Decimal.t/0`, `t:float/0`, `t:integer/0`,
    or `t:binary/0` value, _or_ in options as `default: value` — not both.

    ### Examples

    ```elixir
    iex> get_env_as_decimal("DECIMAL")
    nil

    iex> get_env_as_decimal("DECIMAL", Decimal.new("3.14"))
    Decimal.new("3.14")

    iex> get_env_as_decimal("DECIMAL", 25.5)
    Decimal.new("25.5")

    iex> get_env_as_decimal("DECIMAL", 25)
    Decimal.new("25")

    iex> get_env_as_decimal("DECIMAL", "255")
    Decimal.new("255")

    iex> get_env_as_decimal("DECIMAL", default: Decimal.new("3.14"))
    Decimal.new("3.14")

    iex> get_env_as_decimal("DECIMAL", default: 25.5)
    Decimal.new("25.5")

    iex> get_env_as_decimal("DECIMAL", default: 25)
    Decimal.new("25")

    iex> get_env_as_decimal("DECIMAL", default: "255")
    Decimal.new("255")

    iex> get_env_as_decimal("DECIMAL", default: "3.5R")
    ** (Enviable.OptionError) could not convert environment variable "DECIMAL" to type decimal: `:default` is not a valid decimal

    iex> get_env_as_decimal("DECIMAL", default: %{})
    ** (Enviable.OptionError) could not convert environment variable "DECIMAL" to type decimal: invalid `:default` value (expected Decimal, float, integer, or string)

    iex> put_env("DECIMAL", "1")
    iex> get_env_as_decimal("DECIMAL")
    Decimal.new("1")

    iex> put_env("DECIMAL", "ff")
    iex> get_env_as_decimal("DECIMAL")
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "1.6.0"
    @doc group: "Conversion"
    @spec get_env_as_decimal(
            String.t(),
            Decimal.t() | float() | integer() | String.t() | [unquote(Schema.option_typespec(:decimal))]
          ) :: Decimal.t() | nil
    def get_env_as_decimal(varname, opts \\ [])

    def get_env_as_decimal(varname, default)
        when is_binary(default) or is_float(default) or is_integer(default) or is_struct(default, Decimal),
        do: get_env_as(varname, :decimal, default: default)

    def get_env_as_decimal(varname, opts), do: get_env_as(varname, :decimal, opts)

    @doc """
    Returns the value of an environment variable converted to a `t:Decimal.t/0` value as
    `{:ok, Decimal.t()}` or `:error` if the variable is unset.

    ### Examples

    ```elixir
    iex> fetch_env_as_decimal("UNSET")
    :error

    iex> put_env("DECIMAL", "1")
    iex> fetch_env_as_decimal("DECIMAL")
    {:ok, Decimal.new("1")}

    iex> put_env("DECIMAL", "ff")
    iex> fetch_env_as_decimal("DECIMAL")
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "1.6.0"
    @doc group: "Conversion"
    @spec fetch_env_as_decimal(String.t()) :: {:ok, Decimal.t()} | :error
    def fetch_env_as_decimal(varname) do
      fetch_env_as(varname, :decimal, [])
    end

    @doc """
    Returns the value of an environment variable converted to a `t:Decimal.t/0` value or
    `:error` if the variable is unset.

    ### Examples

    ```elixir
    iex> fetch_env_as_decimal!("UNSET")
    ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

    iex> put_env("DECIMAL", "1")
    iex> fetch_env_as_decimal!("DECIMAL")
    Decimal.new("1")

    iex> put_env("DECIMAL", "ff")
    iex> fetch_env_as_decimal!("DECIMAL")
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "1.6.0"
    @doc group: "Conversion"
    @spec fetch_env_as_decimal!(String.t()) :: Decimal.t()
    def fetch_env_as_decimal!(varname) do
      fetch_env_as!(varname, :decimal, [])
    end
  end

  @doc """
  Returns the value of an environment variable converted to a `t:float/0` value or
  `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_float!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("FLOAT", "1")
  iex> fetch_env_as_float!("FLOAT")
  1.0

  iex> put_env("FLOAT", "ff")
  iex> fetch_env_as_float!("FLOAT")
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_float!(String.t()) :: float()
  def fetch_env_as_float!(varname) do
    fetch_env_as!(varname, :float, [])
  end

  @doc """
  Returns the value of an environment variable converted to
  a `t:Enviable.Conversion.json/0` value or raises an exception if the variable is unset.

  ### Options

  #{Schema.docs(:json, except: [:default])}

  ### Examples

  ```elixir
  iex> fetch_env_as_json!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> fetch_env_as_json!("JSON")
  [%{"foo" => "bar"}]

  iex> put_env("JSON", "ff")
  iex> fetch_env_as_json!("JSON")
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_json!(
          String.t(),
          [unquote(Schema.option_typespec(:json, except: [:default]))]
        ) :: Conversion.json()
  def fetch_env_as_json!(varname, opts \\ []) do
    fetch_env_as!(varname, :json, opts)
  end

  module_options = """
  ### Options

  #{Schema.docs(:module, except: [:default])}
  """

  @doc """
  Returns the value of an environment variable converted to `t:module/0` or raises an
  exception if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.concat/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_module!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("NAME", "Enviable")
  iex> fetch_env_as_module!("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_module!(
          String.t(),
          [unquote(Schema.option_typespec(:module, except: [:default]))]
        ) :: module()
  def fetch_env_as_module!(varname, opts \\ []) do
    fetch_env_as!(varname, :module, opts)
  end

  @doc """
  Returns the value of an environment variable converted to `t:module/0` or raises an
  exception if the variable is unset. The resulting `t:module/0` must already exist.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.safe_concat/1` which will result in an exception
  > if the resulting module is not already known and if used without the `:allowed`
  > option. See #{atom_exhaustion} from the Security Working Group of the Erlang Ecosystem
  > Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> fetch_env_as_safe_module!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("NAME", "Enviable")
  iex> fetch_env_as_safe_module!("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_module!(
          String.t(),
          [unquote(Schema.option_typespec(:safe_module, except: [:default]))]
        ) :: module()
  def fetch_env_as_safe_module!(varname, opts \\ []) do
    fetch_env_as!(varname, :safe_module, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a log level `t:atom/0` for
  `Logger.configure/1` or raises an exception if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_log_level!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("LOG_LEVEL", "critical")
  iex> fetch_env_as_log_level!("LOG_LEVEL")
  :critical
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_log_level!(String.t()) :: Conversion.log_level()
  def fetch_env_as_log_level!(varname) do
    fetch_env_as!(varname, :log_level, [])
  end

  @doc """
  Returns the value of an environment variable converted from a PEM string through
  `:public_key.pem_decode/1` or raises an exception if the variable is unset.

  ### Options

  #{Schema.docs(:pem, except: [:default])}

  ### Examples

  ```elixir
  iex> fetch_env_as_pem!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("PEM", "")
  iex> fetch_env_as_pem!("PEM")
  []
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_pem!(
          String.t(),
          [unquote(Schema.option_typespec(:pem))]
        ) :: Conversion.pem()
  def fetch_env_as_pem!(varname, opts \\ []) do
    fetch_env_as!(varname, :pem, opts)
  end

  @doc """
  Returns the value of an environment variable parsed and evaluated as Erlang code with
  the result , or raises an exception if the environment variable is not set.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded with `{:base64, :erlang}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `:erl_scan.string/1`) and evaluates (with
  > `:erl_parse.parse_term/1`) Erlang code from environment variables in the
  > context of your application. Do not use this with untrusted input.

  ### Examples

  ```elixir
  iex> fetch_env_as_erlang!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("TERM", "{ok, true}.")
  iex> fetch_env_as_erlang!("TERM")
  {:ok, true}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_erlang!(String.t()) :: term()
  def fetch_env_as_erlang!(varname) do
    fetch_env_as!(varname, :erlang, [])
  end

  @doc """
  Returns the value of an environment variable parsed and evaluated as Elixir code with
  the result , or raises an exception if the environment variable is not set.

  This can be used for tuples, complex map declarations, or other expressions difficult to
  represent with other types. Longer code blocks should be encoded as base 64 text and
  decoded with `{:base64, :elixir}`.

  > #### Untrusted Input {: .error}
  >
  > This function parses (with `Code.string_to_quoted/1`) and evaluates (with
  > `Code.eval_quoted/1`) elixir code from environment variables in the context of your
  > application. Do not use this with untrusted input.

  ### Examples

  ```elixir
  iex> fetch_env_as_elixir!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("TERM", "11000..11100//3")
  iex> fetch_env_as_elixir!("TERM")
  11000..11100//3
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_elixir!(String.t()) :: term()
  def fetch_env_as_elixir!(varname) do
    fetch_env_as!(varname, :elixir, [])
  end

  @doc """
  Returns the value of an environment variable decoded from a base 16 string or raises an
  exception if the variable is unset.

  ## Options

  #{Schema.docs(:base16, as: :encoded, except: [:default])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16!("NAME")
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16!("NAME", case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16!("NAME", as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> fetch_env_as_base16!("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base16!(
          String.t(),
          [unquote(Schema.option_typespec(:base16, as: :encoded, except: [:default]))]
        ) :: term()
  def fetch_env_as_base16!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base16, opts}
        {type, opts} -> {{:base16, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 string or raises an
  exception if the variable is unset.

  ## Options

  #{Schema.docs(:base32, as: :encoded, except: [:default])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32!("NAME")
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32!("NAME", case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32!("NAME", as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> fetch_env_as_base32!("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base32!(
          String.t(),
          [unquote(Schema.option_typespec(:base32, as: :encoded, except: [:default]))]
        ) :: term()
  def fetch_env_as_base32!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base32, opts}
        {type, opts} -> {{:base32, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 hex encoded string
  or raises an exception if the variable is unset.

  ## Options

  #{Schema.docs(:hex32, as: :encoded, except: [:default])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32!("NAME")
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32!("NAME", case: :lower)
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32!("NAME", as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> fetch_env_as_hex32!("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_hex32!(
          String.t(),
          [unquote(Schema.option_typespec(:hex32, as: :encoded, except: [:default]))]
        ) :: term()
  def fetch_env_as_hex32!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:hex32, opts}
        {type, opts} -> {{:hex32, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 64 string or raises an
  exception if the variable is unset.

  ## Options

  #{Schema.docs(:base64, as: :encoded, except: [:default])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64!("NAME")
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64!("NAME", padding: false)
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64!("NAME", as: :string, padding: true)
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> fetch_env_as_base64!("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base64!(
          String.t(),
          [unquote(Schema.option_typespec(:base64, as: :encoded, except: [:default]))]
        ) :: term()
  def fetch_env_as_base64!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base64, opts}
        {type, opts} -> {{:base64, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a URL-safe base 64 string or
  raises an exception if the variable is unset.

  ## Options

  #{Schema.docs(:url_base64, as: :encoded, except: [:default])}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64!("NAME")
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64!("NAME", padding: false)
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64!("NAME", as: :string, padding: true)
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> fetch_env_as_url_base64!("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_url_base64!(
          String.t(),
          [unquote(Schema.option_typespec(:url_base64, as: :encoded, except: [:default]))]
        ) :: term()
  def fetch_env_as_url_base64!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:url_base64, opts}
        {type, opts} -> {{:url_base64, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable parsed as a delimiter-separated list.

  ## Options

  #{Schema.docs(:list, as: :list, except: [:default])}

  ### Examples

  ```elixir
  iex> put_env("LIST", "1,2,3")
  iex> fetch_env_as_list!("LIST")
  ["1", "2", "3"]
  iex> fetch_env_as_list!("LIST", as: :integer)
  [1, 2, 3]

  iex> put_env("LIST", "1;2;3")
  iex> fetch_env_as_list!("LIST", delimiter: ";")
  ["1", "2", "3"]
  iex> fetch_env_as_list!("LIST", as: :integer, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_list!(
          String.t(),
          [unquote(Schema.option_typespec(:list, as: :list, except: [:default]))]
        ) :: list()
  def fetch_env_as_list!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:list, opts}
        {type, opts} -> {{:list, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  timeout_values = """
  ### Timeout Values

  Timeout values are specified as non-negative integer values with optional suffixes or
  the word `infinity`. The integer part may have underscores (`_`) separating digits like
  Elixir itself.

  If no suffix is present, the value is in milliseconds. Supported suffixes are:

  - `week`, `weeks`, `w`: the number of weeks (always 7 days)

  - `day`, `days`, `d`: the number of days (always 24 hours)

  - `hour`, `hours`, `h`: the number of hours (always 60 minutes)

  - `minute`, `minutes`, `m`: the number of minutes (always 60 seconds)

  - `second`, `seconds`, `s`: the number of seconds (always 1000 milliseconds)

  - `millisecond`, `milliseconds`, `ms`: the number of milliseconds

  Suffixes may be present with or without a space (`30s` and `30 s` are the same value),
  and multiple timeouts may be chained (`1h 30m`), but may not be duplicated. See
  `Kernel.to_timeout/1` for more details.

  Only lowercase suffixes are supported.
  """

  @doc """
  Returns the value of an environment variable converted to a millisecond `t:timeout/0` or
  a default value if the variable is unset. If no `default` is provided, `:infinity` will
  be returned.

  #{timeout_values}

  ### Options

  #{Schema.docs(:timeout)}

  ### Examples

  ```elixir
  iex> get_env_as_timeout("UNSET")
  :infinity

  iex> get_env_as_timeout("UNSET", "30s")
  30000

  iex> get_env_as_timeout("UNSET", "PT30S")
  30000

  iex> put_env("TIMEOUT", "3_0 seconds")
  iex> get_env_as_timeout("TIMEOUT")
  30000

  iex> put_env("TIMEOUT", "PT30S")
  iex> get_env_as_timeout("TIMEOUT")
  30000
  ```
  """
  @doc since: "1.7.0"
  @doc group: "Conversion"
  @spec get_env_as_timeout(
          String.t(),
          timeout()
          | String.t()
          | Duration.t()
          | [unquote(Schema.option_typespec(:timeout)) | {Conversion.timeout_unit(), non_neg_integer()}]
        ) :: timeout()
  def get_env_as_timeout(varname, opts \\ [])

  def get_env_as_timeout(varname, default)
      when (is_integer(default) and default >= 0) or default == :infinity or is_binary(default) or
             is_struct(default, Duration), do: get_env_as(varname, :timeout, default: default)

  def get_env_as_timeout(varname, []), do: get_env_as(varname, :timeout, [])

  def get_env_as_timeout(varname, opts) do
    opts =
      case Keyword.validate(opts, [:week, :day, :hour, :minute, :second, :millisecond]) do
        {:ok, _} -> [default: opts]
        {:error, _} -> opts
      end

    get_env_as(varname, :timeout, opts)
  end

  @doc """
  Returns the value of an environment variable converted to a millisecond `t:timeout/0` as
  `{:ok, timeout()}` or `:error` if the variable is unset.

  #{timeout_values}

  ### Examples

  ```elixir
  iex> fetch_env_as_timeout("UNSET")
  :error

  iex> put_env("TIMEOUT", "infinity")
  iex> fetch_env_as_timeout("TIMEOUT")
  {:ok, :infinity}

  iex> put_env("TIMEOUT", "3_0 seconds")
  iex> fetch_env_as_timeout("TIMEOUT")
  {:ok, 30000}
  ```
  """
  @doc since: "1.7.0"
  @doc group: "Conversion"
  @spec fetch_env_as_timeout(String.t()) :: {:ok, timeout()} | :error
  def fetch_env_as_timeout(varname) do
    fetch_env_as(varname, :timeout)
  end

  @doc """
  Returns the value of an environment variable converted to a millisecond `t:timeout/0` or
  raises an exception if the variable is unset.

  #{timeout_values}

  ### Examples

  ```elixir
  iex> fetch_env_as_timeout!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("TIMEOUT", "infinity")
  iex> fetch_env_as_timeout!("TIMEOUT")
  :infinity

  iex> put_env("TIMEOUT", "3_0 seconds")
  iex> fetch_env_as_timeout!("TIMEOUT")
  30000
  ```
  """
  @doc since: "1.7.0"
  @doc group: "Conversion"
  @spec fetch_env_as_timeout!(String.t()) :: timeout()
  def fetch_env_as_timeout!(varname) do
    fetch_env_as!(varname, :timeout)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:Duration.t/0` or
  a default value if the variable is unset. If no `default` is provided, `nil` will be
  returned.

  #{timeout_values}

  ### Options

  #{Schema.docs(:duration)}

  ### Examples

  ```elixir
  iex> get_env_as_duration("UNSET")
  nil

  iex> get_env_as_duration("UNSET", "PT30S")
  %Duration{second: 30}

  iex> put_env("TIMEOUT", "PT1H30M")
  iex> get_env_as_duration("TIMEOUT")
  %Duration{hour: 1, minute: 30}
  ```
  """
  @doc since: "2.2.0"
  @doc group: "Conversion"
  @spec get_env_as_duration(
          String.t(),
          String.t() | Duration.t() | [unquote(Schema.option_typespec(:duration))]
        ) :: Duration.t()
  def get_env_as_duration(varname, opts \\ [])

  def get_env_as_duration(varname, default) when is_struct(default, Duration) or is_binary(default),
    do: get_env_as(varname, :duration, default: default)

  def get_env_as_duration(varname, opts), do: get_env_as(varname, :duration, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:Duration.t/0` as
  `{:ok, Duration.t()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_duration("UNSET")
  :error

  iex> put_env("DURATION", "PT30S")
  iex> fetch_env_as_duration("DURATION")
  {:ok, %Duration{second: 30}}

  iex> put_env("DURATION", "PT1H30M")
  iex> fetch_env_as_duration("DURATION")
  {:ok, %Duration{hour: 1, minute: 30}}
  ```
  """
  @doc since: "2.2.0"
  @doc group: "Conversion"
  @spec fetch_env_as_duration(String.t()) :: {:ok, Duration.t()} | :error
  def fetch_env_as_duration(varname) do
    fetch_env_as(varname, :duration)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:Duration.t/0` or raises
  an exception if the variable is unset.

  ### Examples

  ```elixir
  iex> fetch_env_as_duration!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("DURATION", "PT30S")
  iex> fetch_env_as_duration!("DURATION")
  %Duration{second: 30}

  iex> put_env("DURATION", "PT1H30M")
  iex> fetch_env_as_duration!("DURATION")
  %Duration{hour: 1, minute: 30}
  ```
  """
  @doc since: "2.2.0"
  @doc group: "Conversion"
  @spec fetch_env_as_duration!(String.t()) :: Duration.t()
  def fetch_env_as_duration!(varname) do
    fetch_env_as!(varname, :duration)
  end

  @doc """
  Deletes an environment variable, removing `varname` from the environment.

  See `Enviable.Codex.delete_env/1`.
  """
  @doc group: "Env"
  @spec delete_env(String.t() | Value.t()) :: :ok
  defdelegate delete_env(varname), to: Codex

  @doc """
  Returns the value of the given environment variable or `:error` if not found.

  If the environment variable `varname` is set, then `{:ok, value}` is returned where
  value is a string. If `varname` is not set, `:error` is returned.

  See `Enviable.Codex.fetch_env/1`.

  ### Examples

  ```elixir
  iex> fetch_env("PORT")
  :error

  iex> put_env("PORT", "4000")
  iex> fetch_env("PORT")
  {:ok, "4000"}
  ```
  """
  @doc group: "Env"
  @spec fetch_env(String.t() | Value.t()) :: {:ok, String.t()} | :error
  def fetch_env(var) do
    case Codex.fetch_env(var) do
      {:ok, %Value{} = value} -> {:ok, Value.__unwrap__(value)}
      :error -> :error
    end
  end

  @doc """
  Returns the value of the given environment variable or raises if not found.

  Same as `get_env/1` but raises instead of returning `nil` when the variable is not set.

  See `Enviable.Codex.fetch_env!/1`.

  ### Examples

  ```elixir
  iex> fetch_env!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> fetch_env!("UNSET", or_raise: ~S("UNSET" is required))
  ** (RuntimeError) "UNSET" is required

  iex> put_env("PORT", "4000")
  iex> fetch_env!("PORT")
  "4000"
  ```
  """
  @doc group: "Env"
  @spec fetch_env!(String.t() | Value.t(), [{:or_raise, String.t()}]) :: String.t()
  def fetch_env!(var, opts \\ []) do
    Value.__unwrap__(Codex.fetch_env!(var, opts))
  end

  @doc """
  Returns all system environment variables.

  The returned value is a map containing name-value pairs. Variable names and their values
  are strings.

  See `Enviable.Codex.get_env/0`.
  """
  @doc group: "Env"
  @spec get_env() :: Value.env_map()
  defdelegate get_env, to: Codex

  @doc """
  Returns the value of the given environment variable.

  The returned value of the environment variable `varname` is a string. If the environment
  variable is not set, returns the string specified in `default` or `nil` if none is
  specified.

  See `Enviable.Codex.get_env/2`.

  ### Examples

  ```elixir
  iex> get_env("PORT")
  nil

  iex> get_env("PORT", "4001")
  "4001"

  iex> put_env("PORT", "4000")
  iex> get_env("PORT")
  "4000"
  iex> get_env("PORT", "4001")
  "4000"
  ```
  """
  @doc group: "Env"
  @spec get_env(String.t() | Value.t(), default) :: String.t() | default
        when default: String.t() | nil
  def get_env(var, default \\ nil) do
    Value.__unwrap__(Codex.get_env(var, default))
  end

  @doc """
  Sets or deletes an environment variable.

  Sets a new `value` for the environment variable `varname`. If `value` is `nil` or an
  unset `t:Value.t/0`, the variable is deleted. (`System.put_env/2` raises on `nil`.) A
  `t:Value.t/0` `varname` sets the variable with the Value's name.

  See `Enviable.Codex.put_env/2`.

  ### Examples

  ```elixir
  iex> Enviable.put_env("PORT", "4000")
  :ok
  iex> Enviable.get_env("PORT")
  "4000"
  iex> Enviable.put_env("PORT", nil)
  :ok
  iex> Enviable.get_env("PORT")
  nil

  iex> Enviable.put_env(%Enviable.Value{name: "PORT", value: nil}, "4001")
  :ok
  iex> Enviable.get_env("PORT")
  "4001"
  ```
  """
  @doc group: "Env"
  @spec put_env(String.t() | Value.t(), nil | String.t() | Value.t()) :: :ok
  defdelegate put_env(varname, value), to: Codex

  @doc """
  Sets multiple environment variables.

  Sets a new value for each environment variable corresponding to each `{key, value}` pair
  in `enum`. Keys and non-nil values are automatically converted to charlists. `nil`
  values erase the given keys.

  Overall, this is a convenience wrapper around `put_env/2` and `delete_env/2` with
  support for different key and value formats.

  See `Enviable.Codex.put_env/1`.
  """
  @doc group: "Env"
  @spec put_env(Enumerable.t() | Value.t()) :: :ok
  defdelegate put_env(var_map), to: Codex
end
