defmodule Enviable do
  @moduledoc """
  Enviable is a small collection of functions to improve Elixir project configuration via
  environment variables as proposed under the [12-factor][12f] application model. It works
  well with configuration environment loaders like [Dotenvy][Dotenvy] or [Nvir][nvir] and
  provides robust value conversion like [jetenv][jetenv].

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
  > When using Dotenvy, the use of a `side_effect` that calls `System.put_env/1`
  > is **required**, as Enviable works with the system environment variable table.
  > Future versions of Enviable may offer ways to work with the default Dotenvy
  > side effect.

  ### Configuration

  Envible has two compile-time options.

  - `:boolean_downcase`: Sets the default value for case-folding boolean conversions.
    Can be set to `:default`, `:ascii`, `:greek`, or `:turkic`. The boolean value `true`
    will be treated as `:default`.

    ```elixir
    config :enviable, :boolean_downcase, true
    config :enviable, :boolean_downcase, :default
    config :enviable, :boolean_downcase, :ascii
    ```

    If unspecified, defaults to `false`.

    > The next major version of Enviable will change this to `:default`, as it should not

    > #### Default Change {: .info}
    >
    > In the next major version of Enviable, the fallback default `:downcase` value is
    > changing to `:default` instead of `false` as it should not matter whether the
    > matched value is `true`, `TRUE`, or `True` for boolean tests.

  - `:json_engine`: The default JSON engine to use for JSON conversions. This may be
    provided as a `t:module/0` (which must export `decode/1`) or a `t:mfa/0` tuple. When
    provided with a `t:mfa/0`, the variable value will be passed as the first parameter.

    If the engine produces `{:ok, json_value}` or an expected JSON type result, it will be
    considered successful. Any other result will be treated as failure.

    The default JSON engine is `:json` if the Erlang/OTP `m::json` module is available
    (Erlang/OTP 27+) or provided by [json_polyfill][jp]. Otherwise, [Jason][jason] is
    the default engine.

    ```elixir
    config :enviable, :json_engine, :thoas
    config :enviable, :json_engine, {Jason, :decode, [[floats: :decimals]]}
    ```

  [12f]: https://12factor.net/
  [dotenvy]: https://hexdocs.pm/dotenvy/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [jetenv]: https://hexdocs.pm/jetenv/readme.html
  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [nvir]: https://hexdocs.pm/nvir/readme.html
  """

  alias Enviable.Conversion

  @doc """
  Set an environment variable value only if it is not yet set. This is a convenience
  wrapper around `System.put_env/2` and `System.get_env/2`.

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
  @spec put_env_new(String.t(), String.t()) :: :ok
  def put_env_new(varname, value), do: put_env(varname, get_env(varname, value))

  @doc """
  Returns the value of an environment variable converted to the target `type` or a default
  value if the variable is unset. If no `default` is provided, `nil` is returned (unless
  converting to `:boolean`, which will return `false`).

  Supported primitive conversions are:

  - `:atom` (`t:Enviable.Conversion.convert_atom/0`, `get_env_as_atom/2`)
  - `:boolean` (`t:Enviable.Conversion.convert_boolean/0`, `get_env_as_boolean/2`)
  - `:charlist` (`t:Enviable.Conversion.convert_charlist/0`, `get_env_as_charlist/2`)
  - `:decimal` (`t:Enviable.Conversion.convert_decimal/0`, `get_env_as_decimal/2`)
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
  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `get_env_as_timeout/2`),
    supported on Elixir 1.17+

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
  iex> Enviable.get_env_as("UNSET", :atom)
  nil

  iex> Enviable.get_env_as("UNSET", :float)
  nil

  iex> Enviable.get_env_as("UNSET", :base16)
  nil

  iex> Enviable.put_env("NAME", "get_env_as")
  iex> Enviable.get_env_as("NAME", :atom)
  :get_env_as

  iex> Enviable.put_env("NAME", "GET_ENV_AS")
  iex> Enviable.get_env_as("NAME", :safe_atom, downcase: true)
  :get_env_as

  iex> Enviable.get_env_as("FLOAT", :float, default: "3.5")
  3.5

  iex> Enviable.get_env_as("FLOAT", :float, default: 3.5)
  3.5

  iex> Enviable.put_env("FLOAT", "3")
  iex> Enviable.get_env_as("FLOAT", :float)
  3.0

  iex> Enviable.put_env("FLOAT", "3.1")
  iex> Enviable.get_env_as("FLOAT", :float)
  3.1

  iex> red = Base.encode16("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.get_env_as("NAME", :base16, case: :lower)
  "RED"
  iex> Enviable.get_env_as("NAME", {:base16, :string}, case: :lower)
  "RED"
  iex> Enviable.get_env_as("NAME", {:base16, :atom}, case: :lower, downcase: true)
  :red

  iex> Enviable.put_env("LIST", "1,2,3")
  iex> Enviable.get_env_as("LIST", :list)
  ["1", "2", "3"]
  iex> Enviable.get_env_as("LIST", {:list, :integer})
  [1, 2, 3]

  iex> Enviable.put_env("LIST", "1;2;3")
  iex> Enviable.get_env_as("LIST", :list, delimiter: ";")
  ["1", "2", "3"]
  iex> Enviable.get_env_as("LIST", {:list, :integer}, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "1.1.0"
  @doc group: "Conversion"
  @spec get_env_as(String.t(), Conversion.conversion(), keyword) :: nil | term()
  def get_env_as(varname, type, opts \\ []) do
    varname
    |> get_env()
    |> Conversion.convert_as(varname, type, opts)
  end

  atom_exhaustion =
    "[Preventing atom exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)"

  atom_options = """
  ### Options

  - `:allowed`: A list of `t:atom/0` values indicating permitted atoms and used as
    a lookup table, if present. Any value not found will result in an exception.
  - `:default`: The `t:atom/0` or `t:binary/0` value representing the atom value to use if
    the environment variable is unset (`nil`). If the `:allowed` option is present, the
    default value must be one of the permitted values.
  - `:downcase`: See `t:Enviable.Conversion.opt_downcase/0`.
  - `:upcase`: See `t:Enviable.Conversion.opt_upcase/0`.

  A shorthand for the `default` option may be provided as a `t:atom/0` value.
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
  iex> Enviable.get_env_as_atom("UNSET")
  nil

  iex> Enviable.get_env_as_atom("UNSET", :default)
  :default

  iex> Enviable.get_env_as_atom("UNSET", default: :default)
  :default

  iex> Enviable.put_env("NAME", "get_env_as_atom")
  iex> Enviable.get_env_as_atom("NAME")
  :get_env_as_atom
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_atom(
          String.t(),
          atom()
          | binary()
          | [
              {:allowed, list(atom())}
              | {:default, atom() | binary()}
              | Conversion.opt_downcase()
            ]
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
  iex> Enviable.get_env_as_safe_atom("UNSET")
  nil

  iex> Enviable.get_env_as_safe_atom("UNSET", :default)
  :default

  iex> Enviable.get_env_as_safe_atom("UNSET", default: :default)
  :default

  iex> Enviable.put_env("NAME", "GET_ENV_AS_SAFE_ATOM")
  iex> Enviable.get_env_as_safe_atom("NAME", downcase: true)
  :get_env_as_safe_atom
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_safe_atom(
          String.t(),
          atom()
          | binary()
          | [
              {:allowed, list(atom())}
              | {:default, atom() | binary()}
              | Conversion.opt_downcase()
            ]
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

  - `:default`: the default value (which must be `true` or `false`) if the variable is
    unset. In most cases, when `falsy` is provided, `default: true` should also be
    provided.

  - `:truthy`: a list of string values to be compared for truth values. If the value of
    the environment variable matches these values, `true` will be returned; other values
    will result in `false`. Mutually exclusive with `falsy`.

  - `:falsy`: a list of string values to be compared for false values. If the value of the
    environment variable matches these values, `false` will be returned; other values will
    result in `true`. Mutually exclusive with `truthy`.

  - `:downcase`: either `false` (the default), `true`, or the mode parameter for
    `String.downcase/2` (`:default`, `:ascii`, `:greek`, or `:turkic`).

    The default `:downcase` value for boolean conversions can be changed at compile time
    through application configuration:

    ```elixir
    config :enviable, :boolean_downcase, true
    config :enviable, :boolean_downcase, :default
    config :enviable, :boolean_downcase, :ascii
    ```

    > In the next major version of Enviable, the default `:downcase` value will be
    > changing to `:default`.

  A shorthand value for the `default` option may be provided as a `t:boolean/0` value.

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_boolean("FLAG")
  false

  iex> Enviable.get_env_as_boolean("FLAG", true)
  true

  iex> Enviable.get_env_as_boolean("FLAG", default: true)
  true

  iex> Enviable.put_env("FLAG", "1")
  iex> Enviable.get_env_as_boolean("FLAG")
  true

  iex> Enviable.put_env("FLAG", "something")
  iex> Enviable.get_env_as_boolean("FLAG")
  false

  iex> Enviable.put_env("FLAG", "oui")
  iex> Enviable.get_env_as_boolean("FLAG", truthy: ["oui"])
  true

  iex> Enviable.put_env("FLAG", "OUI")
  iex> Enviable.get_env_as_boolean("FLAG", truthy: ["oui"])
  false
  iex> Enviable.get_env_as_boolean("FLAG", truthy: ["oui"], downcase: true)
  true

  iex> Enviable.put_env("FLAG", "NON")
  iex> Enviable.get_env_as_boolean("FLAG", falsy: ["non"])
  true
  iex> Enviable.get_env_as_boolean("FLAG", falsy: ["non"], downcase: true)
  false

  iex> Enviable.get_env_as_boolean("FLAG", default: nil)
  ** (ArgumentError) could not convert environment variable "FLAG" to type boolean: non-boolean `default` value

  iex> Enviable.get_env_as_boolean("FLAG", downcase: nil)
  ** (ArgumentError) could not convert environment variable "FLAG" to type boolean: invalid `downcase` value

  iex> Enviable.get_env_as_boolean("FLAG", truthy: ["oui"], falsy: ["non"])
  ** (ArgumentError) could not convert environment variable "FLAG" to type boolean: `truthy` and `falsy` options both provided
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_boolean(
          String.t(),
          boolean()
          | [
              {:default, boolean()}
              | Conversion.opt_downcase()
              | {:truthy | :falsy, list(binary())}
            ]
        ) :: boolean()
  def get_env_as_boolean(varname, opts \\ [])
  def get_env_as_boolean(varname, default) when is_boolean(default), do: get_env_as(varname, :boolean, default: default)
  def get_env_as_boolean(varname, opts), do: get_env_as(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:charlist/0` or a default
  value if the variable is unset. If no `default` is provided, `nil` is returned.

  ### Options

  - `:default`: The default value, either as a `t:charlist/0` or `t:binary/0`.

  A shorthand for the `default` value may be provided as a `t:binary/0` (there is no guard
  for `t:charlist/0`).

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_charlist("UNDEFINED")
  nil

  iex> Enviable.get_env_as_charlist("UNDEFINED", "default")
  ~c"default"

  iex> Enviable.get_env_as_charlist("UNDEFINED", default: "default")
  ~c"default"

  iex> Enviable.get_env_as_charlist("UNDEFINED", default: ~c"default")
  ~c"default"

  iex> Enviable.put_env("NAME", "get_env_as")
  iex> Enviable.get_env_as_charlist("NAME")
  ~c"get_env_as"
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_charlist(String.t(), binary() | [{:default, charlist() | binary()}]) :: nil | charlist()
  def get_env_as_charlist(varname, opts \\ [])

  def get_env_as_charlist(varname, default) when is_binary(default),
    do: get_env_as(varname, :charlist, default: default)

  def get_env_as_charlist(varname, opts), do: get_env_as(varname, :charlist, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value or
  a default value if the variable is unset. If no `default` is provided, `nil` is
  returned.

  ### Options

  - `:base`: The base (`2..36`) for integer conversion. Defaults to base `10` like
    `String.to_integer/2`.
  - `:default`: the default value, which must be either a binary string value or an
    integer. If provided as a binary, this will be interpreted according to the `base`
    option provided.

  A shorthand for the `default` value may be provided as a `t:integer/0` or `t:binary/0`
  value.

  Failure to parse a binary string `default` or the value of the environment variable will
  result in an exception.

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_integer("PORT")
  nil

  iex> Enviable.get_env_as_integer("PORT", 5432)
  5432

  iex> Enviable.get_env_as_integer("PORT", "5432")
  5432

  iex> Enviable.get_env_as_integer("PORT", default: 5432)
  5432

  iex> Enviable.get_env_as_integer("PORT", default: "5432")
  5432

  iex> Enviable.get_env_as_integer("PORT", default: 3.5)
  ** (ArgumentError) could not convert environment variable "PORT" to type integer: non-integer `default` value

  iex> Enviable.put_env("PORT", "5432")
  iex> Enviable.get_env_as_integer("PORT")
  5432

  iex> Enviable.put_env("PORT", "18eb")
  iex> Enviable.get_env_as_integer("PORT")
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> Enviable.put_env("PORT", "18EB")
  iex> Enviable.get_env_as_integer("PORT", base: 16)
  6379
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_integer(String.t(), integer() | binary() | [{:base, 2..36} | {:default, binary() | integer()}]) ::
          integer() | nil
  def get_env_as_integer(varname, opts \\ [])

  def get_env_as_integer(varname, default) when is_binary(default) or is_integer(default),
    do: get_env_as(varname, :integer, default: default)

  def get_env_as_integer(varname, opts), do: get_env_as(varname, :integer, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:float/0` value or
  a default value if the variable is unset. If no `default` is provided, `nil` will be
  returned.

  ### Options

  - `:default`: The default value, either as `t:float/0`, `t:integer/0` (which will be
    converted to float), or `t:binary/0` (which must parse cleanly as float).

  A shorthand for the `default` value may be provided as a `t:float/0`, `t:integer/0`, or
  `t:binary/0` value.

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_float("FLOAT")
  nil

  iex> Enviable.get_env_as_float("FLOAT", 25.5)
  25.5

  iex> Enviable.get_env_as_float("FLOAT", 25)
  25.0

  iex> Enviable.get_env_as_float("FLOAT", "255")
  255.0

  iex> Enviable.get_env_as_float("FLOAT", default: 25.5)
  25.5

  iex> Enviable.get_env_as_float("FLOAT", default: 25)
  25.0

  iex> Enviable.get_env_as_float("FLOAT", default: "255")
  255.0

  iex> Enviable.get_env_as_float("FLOAT", default: "3.5R")
  ** (ArgumentError) could not convert environment variable "FLOAT" to type float: non-float `default` value

  iex> Enviable.put_env("FLOAT", "1")
  iex> Enviable.get_env_as_float("FLOAT")
  1.0

  iex> Enviable.put_env("FLOAT", "ff")
  iex> Enviable.get_env_as_float("FLOAT")
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_float(String.t(), float() | integer() | binary() | [{:default, binary() | float() | integer()}]) ::
          float() | nil
  def get_env_as_float(varname, opts \\ [])

  def get_env_as_float(varname, default) when is_binary(default) or is_float(default) or is_integer(default),
    do: get_env_as(varname, :float, default: default)

  def get_env_as_float(varname, opts), do: get_env_as(varname, :float, opts)

  @doc """
  Returns the value of an environment variable converted to
  a `t:Enviable.Conversion.json/0` value or a default value if the variable is unset. If
  no `default` is provided, `nil` will be returned.

  ### Options

  - `:default`: The default value, which may be any valid JSON type.
  - `:engine`: The JSON engine to use. May be provided as a `t:module/0` (which must
    export `decode/1`), an arity 1 function, or a `t:mfa/0` tuple. When provided with
    a `t:mfa/0`, the variable value will be passed as the first parameter.

    If the engine produces `{:ok, json_value}` or an expected JSON type result, it will be
    considered successful. Any other result will be treated as failure.

    The default JSON engine is `:json` if the Erlang/OTP `m::json` module is available
    (Erlang/OTP 27+) or provided by [json_polyfill][jp]. Otherwise, [Jason][jason] is
    the default engine. This choice may be overridden with application configuration, as
    this example shows using [Thoas][thoas].

    ```elixir
    import Config

    config :enviable, :json_engine, :thoas
    ```

  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [thoas]: https://hexdocs.pm/thoas/readme.html

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_json("JSON")
  nil

  iex> Enviable.get_env_as_json("JSON", default: "3.5R")
  "3.5R"

  iex> Enviable.put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> Enviable.get_env_as_json("JSON", engine: &Jason.decode!/1)
  [%{"foo" => "bar"}]

  iex> Enviable.put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> Enviable.get_env_as_json("JSON")
  [%{"foo" => "bar"}]

  iex> Enviable.put_env("JSON", "ff")
  iex> Enviable.get_env_as_json("JSON")
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json

  iex> Enviable.put_env("JSON", "ff")
  iex> Enviable.get_env_as_json("JSON", engine: &Jason.decode!/1)
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_json(String.t(), [
          {:default, Conversion.json()}
          | {:engine, module() | (String.t() -> Conversion.json())}
        ]) :: Conversion.json() | nil
  def get_env_as_json(varname, opts \\ []), do: get_env_as(varname, :json, opts)

  module_options = """
  ### Options

  - `:allowed`: A list of `t:module/0` values indicating permitted module and used as
    a lookup table, if present. Any value not found will result in an exception.
  - `:default`: The `t:module/0` or `t:binary/0` value representing the atom value to use
    if the environment variable is unset (`nil`). If the `:allowed` option is present, the
    default value must be one of the permitted values.

  A shorthand for the `default` option may be provided as a `t:atom/0` or `t:binary/0`
  value.
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
  iex> Enviable.get_env_as_module("UNSET")
  nil

  iex> Enviable.get_env_as_module("UNSET", Enviable)
  Elixir.Enviable

  iex> Enviable.put_env("NAME", "Enviable")
  iex> Enviable.get_env_as_module("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_module(
          String.t(),
          module()
          | binary()
          | [{:allowed, list(module())} | {:default, module() | binary()}]
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
  iex> Enviable.get_env_as_safe_module("UNSET")
  nil

  iex> Enviable.get_env_as_safe_module("UNSET", Enviable)
  Elixir.Enviable

  iex> Enviable.put_env("NAME", "Enviable")
  iex> Enviable.get_env_as_safe_module("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_safe_module(
          String.t(),
          binary()
          | module()
          | [{:allowed, list(module())} | {:default, module() | binary()}]
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

  - `:default`: The default value. Must be a valid value.

  A shorthand for the `default` option may be provided as a `t:atom/0` or `t:binary/0`
  value.

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_log_level("LOG_LEVEL")
  nil

  iex> Enviable.get_env_as_log_level("LOG_LEVEL", :error)
  :error

  iex> Enviable.get_env_as_log_level("LOG_LEVEL", "info")
  :info

  iex> Enviable.get_env_as_log_level("LOG_LEVEL", default: :error)
  :error

  iex> Enviable.get_env_as_log_level("LOG_LEVEL", default: "info")
  :info

  iex> Enviable.put_env("LOG_LEVEL", "critical")
  iex> Enviable.get_env_as_log_level("LOG_LEVEL")
  :critical
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_log_level(String.t(), [{:default, Conversion.log_level()}]) :: nil | Conversion.log_level()
  def get_env_as_log_level(varname, opts \\ [])

  def get_env_as_log_level(varname, default) when is_binary(default) or is_atom(default),
    do: get_env_as(varname, :log_level, default: default)

  def get_env_as_log_level(varname, opts), do: get_env_as(varname, :log_level, opts)

  @doc """
  Returns the value of an environment variable converted from a PEM string through
  `:public_key.pem_decode/1` or `nil` if the variable is unset.

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

  ### Examples

  ```elixir
  iex> Enviable.get_env_as_pem("PEM")
  nil

  iex> Enviable.put_env("PEM", "")
  iex> Enviable.get_env_as_pem("PEM")
  []
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_pem(String.t(), [{:filter, boolean() | :cert | :key}]) :: nil | Conversion.pem()
  def get_env_as_pem(varname, opts \\ []), do: get_env_as(varname, :pem, opts)

  @doc """
  Returns the value of an environment variable parsed and evaluated as Erlang code, or
  `nil` if the environment variable is not set.

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
  iex> Enviable.get_env_as_erlang("TERM")
  nil

  iex> Enviable.put_env("TERM", "{ok, true}.")
  iex> Enviable.get_env_as_erlang("TERM")
  {:ok, true}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_erlang(String.t()) :: nil | term()
  def get_env_as_erlang(varname), do: get_env_as(varname, :erlang, [])

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
  iex> Enviable.get_env_as_elixir("TERM")
  nil

  iex> Enviable.put_env("TERM", "11000..11100//3")
  iex> Enviable.get_env_as_elixir("TERM")
  11000..11100//3
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec get_env_as_elixir(String.t()) :: nil | term()
  def get_env_as_elixir(varname), do: get_env_as(varname, :elixir, [])

  @doc """
  Returns the value of an environment variable decoded from a base 16 string or `nil` if
  the environment variable is not set.

  ## Options

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.decode16/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode16("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.get_env_as_base16("NAME", case: :lower)
  "RED"
  iex> Enviable.get_env_as_base16("NAME", as: :string, case: :lower)
  "RED"
  iex> Enviable.get_env_as_base16("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_base16(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
        ]) :: nil | term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  - `:padding`: The boolean value of `:padding` passed to `Base.decode32/2`. The default
    is `false` (the opposite of `Base.decode32/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode32("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.get_env_as_base32("NAME", case: :lower)
  "RED"
  iex> Enviable.get_env_as_base32("NAME", as: :string, case: :lower)
  "RED"
  iex> Enviable.get_env_as_base32("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_base32(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: nil | term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.hex_decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  - `:padding`: The boolean value of `:padding` passed to `hex.decode32/2`. The default
    is `false` (the opposite of `Base.hex_decode32/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.hex_encode32("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.get_env_as_hex32("NAME", case: :lower)
  "RED"
  iex> Enviable.get_env_as_hex32("NAME", as: :string, case: :lower)
  "RED"
  iex> Enviable.get_env_as_hex32("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_hex32(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: nil | term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.
  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode64("RED", padding: true)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.get_env_as_base64("NAME", padding: false)
  "RED"
  iex> Enviable.get_env_as_base64("NAME", as: :string, padding: true)
  "RED"
  iex> Enviable.get_env_as_base64("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_base64(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: nil | term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.
  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.url_encode64("RED", padding: true)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.get_env_as_url_base64("NAME", padding: false)
  "RED"
  iex> Enviable.get_env_as_url_base64("NAME", as: :string, padding: true)
  "RED"
  iex> Enviable.get_env_as_url_base64("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_url_base64(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: nil | term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Each entry must conform to the permitted
    type provided in `:as`.
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

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> Enviable.put_env("LIST", "1,2,3")
  iex> Enviable.get_env_as_list("LIST")
  ["1", "2", "3"]
  iex> Enviable.get_env_as_list("LIST", as: :integer)
  [1, 2, 3]

  iex> Enviable.put_env("LIST", "1;2;3")
  iex> Enviable.get_env_as_list("LIST", delimiter: ";")
  ["1", "2", "3"]
  iex> Enviable.get_env_as_list("LIST", as: :integer, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec get_env_as_list(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:delimiter, String.t(), list(String.t()), Regex.t(), :binary.cp()}
          | {:parts, pos_integer() | :infinity}
          | {:trim, boolean()}
          | {:on, :all | :first | :all_but_first | :none | :all_names | list(binary() | atom())}
          | {:include_captures, boolean()}
        ]) :: nil | list()
  def get_env_as_list(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:list, opts}
        {type, opts} -> {{:list, type}, opts}
      end

    get_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable converted to the target `type` as `{:ok,
  term()}` or `:error` if the variable is unset.

  Supported primitive conversions are:

  - `:atom` (`t:Enviable.Conversion.convert_atom/0`, `fetch_env_as_atom/2`)
  - `:boolean` (`t:Enviable.Conversion.convert_boolean/0`, `fetch_env_as_boolean/2`)
  - `:charlist` (`t:Enviable.Conversion.convert_charlist/0`, `fetch_env_as_charlist/1`)
  - `:decimal` (`t:Enviable.Conversion.convert_decimal/0`, `fetch_env_as_decimal/1`)
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
  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `fetch_env_as_timeout/1`),
    supported on Elixir 1.17+

  Supported encoded conversions are:

  - `:base16` (`t:Enviable.Conversion.encoded_base16/0`, `fetch_env_as_base16/2`)
  - `:base32` (`t:Enviable.Conversion.encoded_base32/0`, `fetch_env_as_base32/2`)
  - `:base64`, `:url_base64` (`t:Enviable.Conversion.encoded_base64/0`,
    `fetch_env_as_base64/2`, `fetch_env_as_url_base64/2`)
  - `:hex32` (`t:Enviable.Conversion.encoded_hex32/0`, `fetch_env_as_hex32/2`)
  - `:list` (`t:Enviable.Conversion.encoded_list/0`, `fetch_env_as_list/2`)

  See `Enviable.Conversion` for supported type conversions and options, but note that any
  `default` values are ignored for `fetch_env_as/3` and related `fetch_env_as_*`
  functions.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as("UNSET", :atom)
  :error

  iex> Enviable.fetch_env_as("UNSET", :float)
  :error

  iex> Enviable.fetch_env_as("UNSET", :base16)
  :error

  iex> Enviable.put_env("NAME", "fetch_env_as")
  iex> Enviable.fetch_env_as("NAME", :atom)
  {:ok, :fetch_env_as}

  iex> Enviable.put_env("NAME", "FETCH_ENV_AS")
  iex> Enviable.fetch_env_as("NAME", :safe_atom, downcase: true)
  {:ok, :fetch_env_as}

  iex> Enviable.fetch_env_as("UNSET", :float, default: "3.5")
  :error

  iex> Enviable.fetch_env_as("UNSET", :float, default: 3.5)
  :error

  iex> Enviable.put_env("FLOAT", "3")
  iex> Enviable.fetch_env_as("FLOAT", :float)
  {:ok, 3.0}

  iex> Enviable.put_env("FLOAT", "3.1")
  iex> Enviable.fetch_env_as("FLOAT", :float)
  {:ok, 3.1}

  iex> red = Base.encode16("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as("NAME", :base16, case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as("NAME", {:base16, :string}, case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as("NAME", {:base16, :atom}, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.1.0"
  @doc group: "Conversion"
  @spec fetch_env_as(String.t(), Conversion.conversion(), keyword) :: {:ok, term()} | :error
  def fetch_env_as(varname, type, opts \\ []) do
    case fetch_env(varname) do
      :error -> :error
      {:ok, value} -> {:ok, Conversion.convert_as(value, varname, type, opts)}
    end
  end

  atom_options = """
  ### Options

  - `:allowed`: A list of `t:atom/0` values indicating permitted atoms and used as
    a lookup table, if present. Any value not found will result in an exception.
  - `:downcase`: See `t:Enviable.Conversion.opt_downcase/0`.
  - `:upcase`: See `t:Enviable.Conversion.opt_upcase/0`.
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
  iex> Enviable.fetch_env_as_atom("UNSET")
  :error

  iex> Enviable.put_env("NAME", "fetch_env_as_atom")
  iex> Enviable.fetch_env_as_atom("NAME")
  {:ok,  :fetch_env_as_atom}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_atom(String.t(), [{:allowed, list(atom())} | Conversion.opt_downcase()]) :: {:ok, atom()} | :error
  def fetch_env_as_atom(varname, opts \\ []), do: fetch_env_as(varname, :atom, opts)

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
  iex> Enviable.fetch_env_as_safe_atom("UNSET")
  :error

  iex> Enviable.put_env("NAME", "FETCH_ENV_AS_SAFE_ATOM")
  iex> Enviable.fetch_env_as_safe_atom("NAME", downcase: true)
  {:ok, :fetch_env_as_safe_atom}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_atom(String.t(), [{:allowed, list(atom())} | Conversion.opt_downcase()]) ::
          {:ok, atom()} | :error
  def fetch_env_as_safe_atom(varname, opts \\ []), do: fetch_env_as(varname, :safe_atom, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value as
  `{:ok, boolean()}` or `:error` if the variable is unset.

  This function will always result in a `t:boolean/0` value. Unless configured with
  `truthy` or `falsy`, only the values `"1"` and `"true"` will be converted to `true` and
  any other value will result in `false`.

  ### Options

  - `:truthy`: a list of string values to be compared for truth values. If the value of the
    environment variable matches these values, `true` will be returned; other values will
    result in `false`. Mutually exclusive with `falsy`.

  - `:falsy`: a list of string values to be compared for false values. If the value of the
    environment variable matches these values, `false` will be returned; other values will
    result in `true`. Mutually exclusive with `truthy`.

  - `:downcase`: either `false` (the default), `true`, or the mode parameter for
    `String.downcase/2` (`:default`, `:ascii`, `:greek`, or `:turkic`).

    The default `:downcase` value for boolean conversions can be changed at compile time
    through application configuration:

    ```elixir
    config :enviable, :boolean_downcase, true
    config :enviable, :boolean_downcase, :default
    config :enviable, :boolean_downcase, :ascii
    ```

    > In the next major version of Enviable, the default `:downcase` value will be
    > changing to `:default`.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_boolean("UNSET")
  :error

  iex> Enviable.put_env("FLAG", "1")
  iex> Enviable.fetch_env_as_boolean("FLAG")
  {:ok, true}

  iex> Enviable.put_env("FLAG", "something")
  iex> Enviable.fetch_env_as_boolean("FLAG")
  {:ok, false}

  iex> Enviable.put_env("FLAG", "oui")
  iex> Enviable.fetch_env_as_boolean("FLAG", truthy: ["oui"])
  {:ok, true}

  iex> Enviable.put_env("FLAG", "OUI")
  iex> Enviable.fetch_env_as_boolean("FLAG", truthy: ["oui"])
  {:ok, false}

  iex> Enviable.put_env("FLAG", "OUI")
  iex> Enviable.fetch_env_as_boolean("FLAG", truthy: ["oui"], downcase: true)
  {:ok, true}

  iex> Enviable.put_env("FLAG", "NON")
  iex> Enviable.fetch_env_as_boolean("FLAG", falsy: ["non"])
  {:ok, true}

  iex> Enviable.put_env("FLAG", "NON")
  iex> Enviable.fetch_env_as_boolean("FLAG", falsy: ["non"], downcase: true)
  {:ok, false}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_boolean(String.t(), [Conversion.opt_downcase() | {:truthy | :falsy, list(binary())}]) ::
          {:ok, boolean} | :error
  def fetch_env_as_boolean(varname, opts \\ []), do: fetch_env_as(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:charlist/0` as `{:ok,
  charlist()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_charlist("UNSET")
  :error

  iex> Enviable.put_env("NAME", "fetch_env_as")
  iex> Enviable.fetch_env_as_charlist("NAME")
  {:ok, ~c"fetch_env_as"}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_charlist(String.t()) :: {:ok, charlist()} | :error
  def fetch_env_as_charlist(varname), do: fetch_env_as(varname, :charlist, [])

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value as
  `{:ok, integer()}` or `:error` if the variable is unset.

  ### Options

  - `:base`: The base (`2..36`) for integer conversion. Defaults to base `10` like
    `String.to_integer/2`.

  Failure to parse the value of the environment variable will result in an exception.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_integer("UNSET")
  :error

  iex> Enviable.put_env("PORT", "5432")
  iex> Enviable.fetch_env_as_integer("PORT")
  {:ok, 5432}

  iex> Enviable.put_env("PORT", "18eb")
  iex> Enviable.fetch_env_as_integer("PORT")
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> Enviable.put_env("PORT", "18EB")
  iex> Enviable.fetch_env_as_integer("PORT", base: 16)
  {:ok, 6379}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_integer(String.t(), [{:base, 2..36}]) :: {:ok, integer()} | :error
  def fetch_env_as_integer(varname, opts \\ []), do: fetch_env_as(varname, :integer, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:float/0` value as `{:ok,
  float()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_float("UNSET")
  :error

  iex> Enviable.put_env("FLOAT", "1")
  iex> Enviable.fetch_env_as_float("FLOAT")
  {:ok, 1.0}

  iex> Enviable.put_env("FLOAT", "ff")
  iex> Enviable.fetch_env_as_float("FLOAT")
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_float(String.t()) :: {:ok, float()} | :error
  def fetch_env_as_float(varname), do: fetch_env_as(varname, :float, [])

  @doc """
  Returns the value of an environment variable converted to
  a `t:Enviable.Conversion.json/0` value as `{:ok, Conversion.json()}` or `:error` if the
  variable is unset.

  ### Options

  - `:engine`: The JSON engine to use. May be provided as a `t:module/0` (which must
    export `decode/1`), an arity 1 function, or a `t:mfa/0` tuple. When provided with
    a `t:mfa/0`, the variable value will be passed as the first parameter.

    If the engine produces `{:ok, json_value}` or an expected JSON type result, it will be
    considered successful. Any other result will be treated as failure.

    The default JSON engine is `:json` if the Erlang/OTP `m::json` module is available
    (Erlang/OTP 27+) or provided by [json_polyfill][jp]. Otherwise, [Jason][jason] is
    the default engine. This choice may be overridden with application configuration, as
    this example shows using [Thoas][thoas].

    ```elixir
    import Config

    config :enviable, :json_engine, :thoas
    ```

  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [thoas]: https://hexdocs.pm/thoas/readme.html

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_json("UNSET")
  :error

  iex> Enviable.put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> Enviable.fetch_env_as_json("JSON")
  {:ok, [%{"foo" => "bar"}]}

  iex> Enviable.put_env("JSON", "ff")
  iex> Enviable.fetch_env_as_json("JSON")
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_json(String.t(), [{:engine, module() | (String.t() -> Conversion.json())}]) ::
          {:ok, Conversion.json()} | :error
  def fetch_env_as_json(varname, opts \\ []), do: fetch_env_as(varname, :json, opts)

  module_options = """
  ### Options

  - `:allowed`: A list of `t:module/0` values indicating permitted module and used as
    a lookup table, if present. Any value not found will result in an exception.
  """

  @doc """
  Returns the value of an environment variable converted to `t:module/0` as `{:ok,
  module()}` or `:error` if the variable is unset.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.concat/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_module("UNSET")
  :error

  iex> Enviable.put_env("NAME", "Enviable")
  iex> Enviable.fetch_env_as_module("NAME")
  {:ok, Elixir.Enviable}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_module(String.t(), [{:allowed, list(module())}]) :: {:ok, module()} | :error
  def fetch_env_as_module(varname, opts \\ []), do: fetch_env_as(varname, :module, opts)

  @doc """
  Returns the value of an environment variable converted to `t:module/0` as `{:ok,
  module()}` or `:error` if the variable is unset.  The resulting `t:module/0` must
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
  iex> Enviable.fetch_env_as_safe_module("UNSET")
  :error

  iex> Enviable.put_env("NAME", "Enviable")
  iex> Enviable.fetch_env_as_safe_module("NAME")
  {:ok, Elixir.Enviable}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_module(String.t(), [{:allowed, list(module())}]) :: {:ok, module()} | :error
  def fetch_env_as_safe_module(varname, opts \\ []), do: fetch_env_as(varname, :safe_module, opts)

  @doc """
  Returns the value of an environment variable converted to a log level `t:atom/0` for
  `Logger.configure/1` as `{:ok, atom()}` or `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_log_level("UNSET")
  :error

  iex> Enviable.put_env("LOG_LEVEL", "critical")
  iex> Enviable.fetch_env_as_log_level("LOG_LEVEL")
  {:ok, :critical}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_log_level(String.t()) :: {:ok, Conversion.log_level()} | :error
  def fetch_env_as_log_level(varname), do: fetch_env_as(varname, :log_level, [])

  @doc """
  Returns the value of an environment variable converted from a PEM string through
  `:public_key.pem_decode/1` as `{:ok, value}` or `:error` if the variable is unset.

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

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_pem("UNSET")
  :error

  iex> Enviable.put_env("PEM", "")
  iex> Enviable.fetch_env_as_pem("PEM")
  {:ok, []}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_pem(String.t(), [{:filter, boolean() | :cert | :key}]) :: {:ok, Conversion.pem()} | :error
  def fetch_env_as_pem(varname, opts \\ []), do: fetch_env_as(varname, :pem, opts)

  @doc """
  Returns the value of an environment variable parsed and evaluated as Erlang code with
  the result as `{:ok, term()}`, or `:error` if the environment variable is not set.

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
  iex> Enviable.fetch_env_as_erlang("UNSET")
  :error

  iex> Enviable.put_env("TERM", "{ok, true}.")
  iex> Enviable.fetch_env_as_erlang("TERM")
  {:ok, {:ok, true}}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_erlang(String.t()) :: {:ok, term()} | :error
  def fetch_env_as_erlang(varname), do: fetch_env_as(varname, :erlang, [])

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
  iex> Enviable.fetch_env_as_elixir("UNSET")
  :error

  iex> Enviable.put_env("TERM", "11000..11100//3")
  iex> Enviable.fetch_env_as_elixir("TERM")
  {:ok, 11000..11100//3}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_elixir(String.t()) :: {:ok, term()} | :error
  def fetch_env_as_elixir(varname), do: fetch_env_as(varname, :elixir, [])

  @doc """
  Returns the value of an environment variable decoded from a base 16 string as `{:ok,
  term()}` or `:error` if the environment variable is not set.

  ## Options

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.decode16/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode16("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_base16("NAME", case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_base16("NAME", as: :string, case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_base16("NAME", as: :atom, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base16(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
        ]) :: :error | {:ok, term()}
  def fetch_env_as_base16(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base16, opts}
        {type, opts} -> {{:base16, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 string as `{:ok,
  term()}` or `:error` if the environment variable is not set.

  ## Options

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  - `:padding`: The boolean value of `:padding` passed to `Base.decode32/2`. The default
    is `false` (the opposite of `Base.decode32/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode32("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_base32("NAME", case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_base32("NAME", as: :string, case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_base32("NAME", as: :atom, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base32(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: :error | {:ok, term()}
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.hex_decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  - `:padding`: The boolean value of `:padding` passed to `hex.decode32/2`. The default
    is `false` (the opposite of `Base.hex_decode32/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.hex_encode32("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_hex32("NAME", case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_hex32("NAME", as: :string, case: :lower)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_hex32("NAME", as: :atom, case: :lower, downcase: true)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_hex32(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: :error | {:ok, term()}
  def fetch_env_as_hex32(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:hex32, opts}
        {type, opts} -> {{:hex32, type}, opts}
      end

    fetch_env_as(varname, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 64 string as `{:ok,
  term()}` or `:error` if the environment variable is not set.

  ## Options

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.
  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode64("RED", padding: true)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_base64("NAME", padding: false)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_base64("NAME", as: :string, padding: true)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_base64("NAME", as: :atom, downcase: true, padding: false)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base64(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: :error | {:ok, term()}
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.
  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.url_encode64("RED", padding: true)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_url_base64("NAME", padding: false)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_url_base64("NAME", as: :string, padding: true)
  {:ok, "RED"}
  iex> Enviable.fetch_env_as_url_base64("NAME", as: :atom, downcase: true, padding: false)
  {:ok, :red}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_url_base64(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: :error | {:ok, term()}
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Each entry must conform to the permitted
    type provided in `:as`.
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

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> Enviable.put_env("LIST", "1,2,3")
  iex> Enviable.fetch_env_as_list("LIST")
  {:ok, ["1", "2", "3"]}
  iex> Enviable.fetch_env_as_list("LIST", as: :integer)
  {:ok, [1, 2, 3]}

  iex> Enviable.put_env("LIST", "1;2;3")
  iex> Enviable.fetch_env_as_list("LIST", delimiter: ";")
  {:ok, ["1", "2", "3"]}
  iex> Enviable.fetch_env_as_list("LIST", as: :integer, delimiter: ";")
  {:ok, [1, 2, 3]}
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_list(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:delimiter, String.t(), list(String.t()), Regex.t(), :binary.cp()}
          | {:parts, pos_integer() | :infinity}
          | {:trim, boolean()}
          | {:on, :all | :first | :all_but_first | :none | :all_names | list(binary() | atom())}
          | {:include_captures, boolean()}
        ]) :: :error | {:ok, list()}
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
  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `fetch_env_as_timeout!/2`),
    supported on Elixir 1.17+

  Supported encoded conversions are:

  - `:base16` (`t:Enviable.Conversion.encoded_base16/0`, `fetch_env_as_base16!/2`)
  - `:base32` (`t:Enviable.Conversion.encoded_base32/0`, `fetch_env_as_base32!/2`)
  - `:base64`, `:url_base64` (`t:Enviable.Conversion.encoded_base64/0`,
    `fetch_env_as_base64!/2`, `fetch_env_as_url_base64!/2`)
  - `:hex32` (`t:Enviable.Conversion.encoded_hex32/0`, `fetch_env_as_hex32!/2`)
  - `:list` (`t:Enviable.Conversion.encoded_list/0`, `fetch_env_as_list!/2`)

  See `Enviable.Conversion` for supported type conversions and options, but note that any
  documented `default` values are ignored for `fetch_env_as!/3` and related
  `fetch_env_as_*!` functions.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as!("UNSET", :atom)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.fetch_env_as!("UNSET", :float)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.fetch_env_as!("UNSET", :base16)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("NAME", "fetch_env_as!")
  iex> Enviable.fetch_env_as!("NAME", :atom)
  :fetch_env_as!

  iex> Enviable.put_env("NAME", "FETCH_ENV_AS!")
  iex> Enviable.fetch_env_as!("NAME", :safe_atom, downcase: true)
  :fetch_env_as!

  iex> Enviable.fetch_env_as!("UNSET", :float, default: "3.5")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.fetch_env_as!("UNSET", :float, default: 3.5)
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("FLOAT", "3")
  iex> Enviable.fetch_env_as!("FLOAT", :float)
  3.0

  iex> Enviable.put_env("FLOAT", "3.1")
  iex> Enviable.fetch_env_as!("FLOAT", :float)
  3.1

  iex> red = Base.encode16("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as!("NAME", :base16, case: :lower)
  "RED"
  iex> Enviable.fetch_env_as!("NAME", {:base16, :string}, case: :lower)
  "RED"
  iex> Enviable.fetch_env_as!("NAME", {:base16, :atom}, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.1.0"
  @doc group: "Conversion"
  @spec fetch_env_as!(String.t(), Conversion.conversion(), keyword) :: term()
  def fetch_env_as!(varname, type, opts \\ []) do
    varname
    |> fetch_env!()
    |> Conversion.convert_as(varname, type, opts)
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
  iex> Enviable.fetch_env_as_atom!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("NAME", "fetch_env_as_atom!")
  iex> Enviable.fetch_env_as_atom!("NAME")
  :fetch_env_as_atom!
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_atom!(String.t(), [{:allowed, list(atom())} | Conversion.opt_downcase()]) :: atom()
  def fetch_env_as_atom!(varname, opts \\ []), do: fetch_env_as!(varname, :atom, opts)

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
  iex> Enviable.fetch_env_as_safe_atom!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("NAME", "FETCH_ENV_AS_SAFE_ATOM!")
  iex> Enviable.fetch_env_as_safe_atom!("NAME", downcase: true)
  :fetch_env_as_safe_atom!
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_atom!(String.t(), [{:allowed, list(atom())} | Conversion.opt_downcase()]) ::
          atom()
  def fetch_env_as_safe_atom!(varname, opts \\ []), do: fetch_env_as!(varname, :safe_atom, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value or
  raises an exception if the variable is unset.

  This function will always result in a `t:boolean/0` value. Unless configured with
  `truthy` or `falsy`, only the values `"1"` and `"true"` will be converted to `true` and
  any other value will result in `false`.

  ### Options

  - `:truthy`: a list of string values to be compared for truth values. If the value of
    the environment variable matches these values, `true` will be returned; other values
    will result in `false`. Mutually exclusive with `falsy`.

  - `:falsy`: a list of string values to be compared for false values. If the value of the
    environment variable matches these values, `false` will be returned; other values will
    result in `true`. Mutually exclusive with `truthy`.

  - `:downcase`: either `false` (the default), `true`, or the mode parameter for
    `String.downcase/2` (`:default`, `:ascii`, `:greek`, or `:turkic`).

    The default `:downcase` value for boolean conversions can be changed at compile time
    through application configuration:

    ```elixir
    config :enviable, :boolean_downcase, true
    config :enviable, :boolean_downcase, :default
    config :enviable, :boolean_downcase, :ascii
    ```

    > In the next major version of Enviable, the default `:downcase` value will be
    > changing to `:default`.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_boolean!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("FLAG", "1")
  iex> Enviable.fetch_env_as_boolean!("FLAG")
  true

  iex> Enviable.put_env("FLAG", "something")
  iex> Enviable.fetch_env_as_boolean!("FLAG")
  false

  iex> Enviable.put_env("FLAG", "oui")
  iex> Enviable.fetch_env_as_boolean!("FLAG", truthy: ["oui"])
  true

  iex> Enviable.put_env("FLAG", "OUI")
  iex> Enviable.fetch_env_as_boolean!("FLAG", truthy: ["oui"])
  false

  iex> Enviable.put_env("FLAG", "OUI")
  iex> Enviable.fetch_env_as_boolean!("FLAG", truthy: ["oui"], downcase: true)
  true

  iex> Enviable.put_env("FLAG", "NON")
  iex> Enviable.fetch_env_as_boolean!("FLAG", falsy: ["non"])
  true

  iex> Enviable.put_env("FLAG", "NON")
  iex> Enviable.fetch_env_as_boolean!("FLAG", falsy: ["non"], downcase: true)
  false
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_boolean!(String.t(), [Conversion.opt_downcase() | {:truthy | :falsy, list(binary())}]) ::
          boolean
  def fetch_env_as_boolean!(varname, opts \\ []), do: fetch_env_as!(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:charlist/0` or raises an
  exception if the variable is unset.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_charlist!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("NAME", "fetch_env_as")
  iex> Enviable.fetch_env_as_charlist!("NAME")
  ~c"fetch_env_as"
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_charlist!(String.t()) :: charlist()
  def fetch_env_as_charlist!(varname), do: fetch_env_as!(varname, :charlist, [])

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value or
  raises an exception if the variable is unset.

  ### Options

  - `:base`: The base (`2..36`) for integer conversion. Defaults to base `10` like
    `String.to_integer/2`.

  Failure to parse the value of the environment variable will result in an exception.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_integer!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("PORT", "5432")
  iex> Enviable.fetch_env_as_integer!("PORT")
  5432

  iex> Enviable.put_env("PORT", "18eb")
  iex> Enviable.fetch_env_as_integer!("PORT")
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> Enviable.put_env("PORT", "18EB")
  iex> Enviable.fetch_env_as_integer!("PORT", base: 16)
  6379
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_integer!(String.t(), [{:base, 2..36}]) :: integer()
  def fetch_env_as_integer!(varname, opts \\ []), do: fetch_env_as!(varname, :integer, opts)

  if Code.ensure_loaded?(Decimal) do
    @doc """
    Returns the value of an environment variable converted to a `t:Decimal.t/0` value or
    a default value if the variable is unset. If no `default` is provided, `nil` will be
    returned.

    ### Options

    - `:default`: The default value, either as `t:Decimal.t/0`, `t:float/0`, `t:integer/0`,
      or `t:binary/0` (the latter three must convert cleanly to `t:Decimal.t/0`).

    A shorthand for the `default` value may be provided as a `t:Decimal.t/0`, `t:float/0`,
    `t:integer/0`, or `t:binary/0` value.

    ### Examples

    ```elixir
    iex> Enviable.get_env_as_decimal("DECIMAL")
    nil

    iex> Enviable.get_env_as_decimal("DECIMAL", Decimal.new("3.14"))
    Decimal.new("3.14")

    iex> Enviable.get_env_as_decimal("DECIMAL", 25.5)
    Decimal.new("25.5")

    iex> Enviable.get_env_as_decimal("DECIMAL", 25)
    Decimal.new("25")

    iex> Enviable.get_env_as_decimal("DECIMAL", "255")
    Decimal.new("255")

    iex> Enviable.get_env_as_decimal("DECIMAL", default: Decimal.new("3.14"))
    Decimal.new("3.14")

    iex> Enviable.get_env_as_decimal("DECIMAL", default: 25.5)
    Decimal.new("25.5")

    iex> Enviable.get_env_as_decimal("DECIMAL", default: 25)
    Decimal.new("25")

    iex> Enviable.get_env_as_decimal("DECIMAL", default: "255")
    Decimal.new("255")

    iex> Enviable.get_env_as_decimal("DECIMAL", default: "3.5R")
    ** (ArgumentError) could not convert environment variable "DECIMAL" to type decimal: invalid decimal `default` value

    iex> Enviable.get_env_as_decimal("DECIMAL", default: %{})
    ** (ArgumentError) could not convert environment variable "DECIMAL" to type decimal: invalid decimal `default` value

    iex> Enviable.put_env("DECIMAL", "1")
    iex> Enviable.get_env_as_decimal("DECIMAL")
    Decimal.new("1")

    iex> Enviable.put_env("DECIMAL", "ff")
    iex> Enviable.get_env_as_decimal("DECIMAL")
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "1.6.0"
    @doc group: "Conversion"
    @spec get_env_as_decimal(
            String.t(),
            Decimal.t() | float() | integer() | binary() | [{:default, Decimal.t() | binary() | float() | integer()}]
          ) ::
            Decimal.t() | nil
    def get_env_as_decimal(varname, opts \\ [])

    def get_env_as_decimal(varname, default)
        when is_binary(default) or is_float(default) or is_integer(default) or is_struct(default, Decimal),
        do: get_env_as(varname, :decimal, default: default)

    def get_env_as_decimal(varname, opts), do: get_env_as(varname, :decimal, opts)

    @doc """
    Returns the value of an environment variable converted to a `t:Decimal.t/0` value as `{:ok,
    Decimal.t()}` or `:error` if the variable is unset.

    ### Examples

    ```elixir
    iex> Enviable.fetch_env_as_decimal("UNSET")
    :error

    iex> Enviable.put_env("DECIMAL", "1")
    iex> Enviable.fetch_env_as_decimal("DECIMAL")
    {:ok, Decimal.new("1")}

    iex> Enviable.put_env("DECIMAL", "ff")
    iex> Enviable.fetch_env_as_decimal("DECIMAL")
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "1.6.0"
    @doc group: "Conversion"
    @spec fetch_env_as_decimal(String.t()) :: {:ok, Decimal.t()} | :error
    def fetch_env_as_decimal(varname), do: fetch_env_as(varname, :decimal, [])

    @doc """
    Returns the value of an environment variable converted to a `t:Decimal.t/0` value or
    `:error` if the variable is unset.

    ### Examples

    ```elixir
    iex> Enviable.fetch_env_as_decimal!("UNSET")
    ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

    iex> Enviable.put_env("DECIMAL", "1")
    iex> Enviable.fetch_env_as_decimal!("DECIMAL")
    Decimal.new("1")

    iex> Enviable.put_env("DECIMAL", "ff")
    iex> Enviable.fetch_env_as_decimal!("DECIMAL")
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "1.6.0"
    @doc group: "Conversion"
    @spec fetch_env_as_decimal!(String.t()) :: Decimal.t()
    def fetch_env_as_decimal!(varname), do: fetch_env_as!(varname, :decimal, [])
  end

  @doc """
  Returns the value of an environment variable converted to a `t:float/0` value or
  `:error` if the variable is unset.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_float!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("FLOAT", "1")
  iex> Enviable.fetch_env_as_float!("FLOAT")
  1.0

  iex> Enviable.put_env("FLOAT", "ff")
  iex> Enviable.fetch_env_as_float!("FLOAT")
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_float!(String.t()) :: float()
  def fetch_env_as_float!(varname), do: fetch_env_as!(varname, :float, [])

  @doc """
  Returns the value of an environment variable converted to
  a `t:Enviable.Conversion.json/0` value or raises an exception if the variable is unset.

  ### Options

  - `:engine`: The JSON engine to use. May be provided as a `t:module/0` (which must
    export `decode/1`), an arity 1 function, or a `t:mfa/0` tuple. When provided with
    a `t:mfa/0`, the variable value will be passed as the first parameter.

    If the engine produces `{:ok, json_value}` or an expected JSON type result, it will be
    considered successful. Any other result will be treated as failure.

    The default JSON engine is `:json` if the Erlang/OTP `m::json` module is available
    (Erlang/OTP 27+) or provided by [json_polyfill][jp]. Otherwise, [Jason][jason] is
    the default engine. This choice may be overridden with application configuration, as
    this example shows using [Thoas][thoas].

    ```elixir
    import Config

    config :enviable, :json_engine, :thoas
    ```

  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [thoas]: https://hexdocs.pm/thoas/readme.html

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_json!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> Enviable.fetch_env_as_json!("JSON")
  [%{"foo" => "bar"}]

  iex> Enviable.put_env("JSON", "ff")
  iex> Enviable.fetch_env_as_json!("JSON")
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_json!(String.t(), [{:engine, module() | (String.t() -> Conversion.json())}]) ::
          Conversion.json()
  def fetch_env_as_json!(varname, opts \\ []), do: fetch_env_as!(varname, :json, opts)

  module_options = """
  ### Options

  - `:allowed`: A list of `t:module/0` values indicating permitted module and used as
    a lookup table, if present. Any value not found will result in an exception.
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
  iex> Enviable.fetch_env_as_module!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("NAME", "Enviable")
  iex> Enviable.fetch_env_as_module!("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_module!(String.t(), [{:allowed, list(module())}]) :: module()
  def fetch_env_as_module!(varname, opts \\ []), do: fetch_env_as!(varname, :module, opts)

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
  iex> Enviable.fetch_env_as_safe_module!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("NAME", "Enviable")
  iex> Enviable.fetch_env_as_safe_module!("NAME")
  Elixir.Enviable
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_safe_module!(String.t(), [{:allowed, list(module())}]) :: module()
  def fetch_env_as_safe_module!(varname, opts \\ []), do: fetch_env_as!(varname, :safe_module, opts)

  @doc """
  Returns the value of an environment variable converted to a log level `t:atom/0` for
  `Logger.configure/1` or raises an exception if the variable is unset.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_log_level!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("LOG_LEVEL", "critical")
  iex> Enviable.fetch_env_as_log_level!("LOG_LEVEL")
  :critical
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_log_level!(String.t()) :: Conversion.log_level()
  def fetch_env_as_log_level!(varname), do: fetch_env_as!(varname, :log_level, [])

  @doc """
  Returns the value of an environment variable converted from a PEM string through
  `:public_key.pem_decode/1` or raises an exception if the variable is unset.

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

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_as_pem!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("PEM", "")
  iex> Enviable.fetch_env_as_pem!("PEM")
  []
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_pem!(String.t(), [{:filter, boolean() | :cert | :key}]) :: Conversion.pem()
  def fetch_env_as_pem!(varname, opts \\ []), do: fetch_env_as!(varname, :pem, opts)

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
  iex> Enviable.fetch_env_as_erlang!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("TERM", "{ok, true}.")
  iex> Enviable.fetch_env_as_erlang!("TERM")
  {:ok, true}
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_erlang!(String.t()) :: term()
  def fetch_env_as_erlang!(varname), do: fetch_env_as!(varname, :erlang, [])

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
  iex> Enviable.fetch_env_as_elixir!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("TERM", "11000..11100//3")
  iex> Enviable.fetch_env_as_elixir!("TERM")
  11000..11100//3
  ```
  """
  @doc since: "1.3.0"
  @doc group: "Conversion"
  @spec fetch_env_as_elixir!(String.t()) :: term()
  def fetch_env_as_elixir!(varname), do: fetch_env_as!(varname, :elixir, [])

  @doc """
  Returns the value of an environment variable decoded from a base 16 string or raises an
  exception if the variable is unset.

  ## Options

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.decode16/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode16("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_base16!("NAME", case: :lower)
  "RED"
  iex> Enviable.fetch_env_as_base16!("NAME", as: :string, case: :lower)
  "RED"
  iex> Enviable.fetch_env_as_base16!("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base16!(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
        ]) :: term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  - `:padding`: The boolean value of `:padding` passed to `Base.decode32/2`. The default
    is `false` (the opposite of `Base.decode32/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode32("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_base32!("NAME", case: :lower)
  "RED"
  iex> Enviable.fetch_env_as_base32!("NAME", as: :string, case: :lower)
  "RED"
  iex> Enviable.fetch_env_as_base32!("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base32!(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.

  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.

  - `:case`: The value of `:case` passed to `Base.hex_decode32/2`, which must be `:upper`,
    `:lower`, or `:mixed`.

    > The next major version of Enviable will change this to `:mixed`, as it should not
    > matter whether the matched value is `b0ba`, `B0BA`, or `b0Ba`.

  - `:padding`: The boolean value of `:padding` passed to `hex.decode32/2`. The default
    is `false` (the opposite of `Base.hex_decode32/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.hex_encode32("RED", case: :lower)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_hex32!("NAME", case: :lower)
  "RED"
  iex> Enviable.fetch_env_as_hex32!("NAME", as: :string, case: :lower)
  "RED"
  iex> Enviable.fetch_env_as_hex32!("NAME", as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_hex32!(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.
  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.encode64("RED", padding: true)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_base64!("NAME", padding: false)
  "RED"
  iex> Enviable.fetch_env_as_base64!("NAME", as: :string, padding: true)
  "RED"
  iex> Enviable.fetch_env_as_base64!("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_base64!(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Must conform to the permitted type provided
    in `:as`.
  - `:ignore_whitespace`: Whether to ignore whitespace values. The default is `true`,
    the opposite default for both `Base.decode64/2` and `Base.url_decode64/2`.
  - `:padding`: The boolean value of `:padding` passed to `Base.decode64/2`. The default
    is `false` (the opposite of `Base.decode64/2`).

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> red = Base.url_encode64("RED", padding: true)
  iex> Enviable.put_env("NAME", red)
  iex> Enviable.fetch_env_as_url_base64!("NAME", padding: false)
  "RED"
  iex> Enviable.fetch_env_as_url_base64!("NAME", as: :string, padding: true)
  "RED"
  iex> Enviable.fetch_env_as_url_base64!("NAME", as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_url_base64!(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:case, :upper | :lower | :mixed}
          | {:padding, boolean()}
        ]) :: term()
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

  - `:as`: The type of value that the encoded string is to be parsed as once decoded.
    Must be either `:string` (the same as not providing `as: :string`) or
    a `t:Conversion.primit/0` value.
  - `:default`: The default value to be used. Each entry must conform to the permitted
    type provided in `:as`.
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

  If `:as` is provided, the options for that type may also be provided.

  ### Examples

  ```elixir
  iex> Enviable.put_env("LIST", "1,2,3")
  iex> Enviable.fetch_env_as_list!("LIST")
  ["1", "2", "3"]
  iex> Enviable.fetch_env_as_list!("LIST", as: :integer)
  [1, 2, 3]

  iex> Enviable.put_env("LIST", "1;2;3")
  iex> Enviable.fetch_env_as_list!("LIST", delimiter: ";")
  ["1", "2", "3"]
  iex> Enviable.fetch_env_as_list!("LIST", as: :integer, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "1.4.0"
  @doc group: "Conversion"
  @spec fetch_env_as_list!(String.t(), [
          {:default, term()}
          | {:as, :string | Conversion.primitive()}
          | {:delimiter, String.t(), list(String.t()), Regex.t(), :binary.cp()}
          | {:parts, pos_integer() | :infinity}
          | {:trim, boolean()}
          | {:on, :all | :first | :all_but_first | :none | :all_names | list(binary() | atom())}
          | {:include_captures, boolean()}
        ]) :: list()
  def fetch_env_as_list!(varname, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:list, opts}
        {type, opts} -> {{:list, type}, opts}
      end

    fetch_env_as!(varname, type, opts)
  end

  if function_exported?(Kernel, :to_timeout, 1) do
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

    - `:default`: The default value. This may be a timeout value described above,
      a `t:Duration.t/0`, a `t:timeout/0` value, or a `t:keyword/0` list where the keys may
      be `:week`, `:day`, `:hour`, `:minute`, `:second`, or `:millisecond` as described in
      `Kernel.to_timeout/1`.

    ### Examples

    ```elixir
    iex> Enviable.get_env_as_timeout("UNSET")
    :infinity

    iex> Enviable.get_env_as_timeout("UNSET", "30s")
    30000

    iex> Enviable.put_env("TIMEOUT", "3_0 seconds")
    iex> Enviable.get_env_as_timeout("TIMEOUT")
    30000
    ```
    """
    @doc since: "1.7.0"
    @doc group: "Conversion"
    @spec get_env_as_timeout(
            String.t(),
            Conversion.timeout_default() | [{:default, Conversion.timeout_default()}]
          ) :: timeout()
    def get_env_as_timeout(varname, opts \\ [])

    def get_env_as_timeout(varname, default)
        when (is_integer(default) and default >= 0) or default == :infinity or is_binary(default) or
               is_struct(default, Duration),
        do: get_env_as(varname, :timeout, default: default)

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
    iex> Enviable.fetch_env_as_timeout("UNSET")
    :error

    iex> Enviable.put_env("TIMEOUT", "infinity")
    iex> Enviable.fetch_env_as_timeout("TIMEOUT")
    {:ok, :infinity}

    iex> Enviable.put_env("TIMEOUT", "3_0 seconds")
    iex> Enviable.fetch_env_as_timeout("TIMEOUT")
    {:ok, 30000}
    ```
    """
    @doc since: "1.7.0"
    @doc group: "Conversion"
    @spec fetch_env_as_timeout(String.t()) :: {:ok, timeout()} | :error
    def fetch_env_as_timeout(varname), do: fetch_env_as(varname, :timeout)

    @doc """
    Returns the value of an environment variable converted to a millisecond `t:timeout/0`
    or raises an exception if the variable is unset.

    #{timeout_values}

    ### Examples

    ```elixir
    iex> Enviable.fetch_env_as_timeout!("UNSET")
    ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

    iex> Enviable.put_env("TIMEOUT", "infinity")
    iex> Enviable.fetch_env_as_timeout!("TIMEOUT")
    :infinity

    iex> Enviable.put_env("TIMEOUT", "3_0 seconds")
    iex> Enviable.fetch_env_as_timeout!("TIMEOUT")
    30000
    ```
    """
    @doc since: "1.7.0"
    @doc group: "Conversion"
    @spec fetch_env_as_timeout!(String.t()) :: timeout()
    def fetch_env_as_timeout!(varname), do: fetch_env_as!(varname, :timeout)
  end

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value.

  Prefer using `get_env_as_boolean/2`.

  ### Examples

  ```elixir
  iex> Enviable.get_env_boolean("UNSET")
  false
  ```
  """
  @doc deprecated: "Use get_env_as_boolean/2 or get_env_as/3 instead"
  @doc group: "Conversion"
  @spec get_env_boolean(String.t(), keyword) :: boolean()
  def get_env_boolean(varname, opts \\ []), do: get_env_as(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable as `{:ok, boolean()}` value or `:error` if
  the variable is unset.

  Prefer using `fetch_env_as_boolean/2`.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_boolean("UNSET")
  :error

  iex> Enviable.put_env("FLAG", "1")
  iex> Enviable.fetch_env_boolean("FLAG")
  {:ok, true}
  ```
  """
  @doc deprecated: "Use fetch_env_as_boolean/2 or fetch_env_as/3 instead"
  @doc group: "Conversion"
  @spec fetch_env_boolean(String.t(), keyword) :: {:ok, boolean()} | :error
  def fetch_env_boolean(varname, opts \\ []), do: fetch_env_as(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:boolean/0` value or
  raises an exception if the variable is unset.

  Prefer using `fetch_env_as_boolean!/2`.

  ```elixir
  iex> Enviable.fetch_env_boolean!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("FLAG", "1")
  iex> Enviable.fetch_env_boolean!("FLAG")
  true
  ```
  """
  @doc deprecated: "Use fetch_env_as_boolean!/2 or fetch_env_as!/3 instead"
  @doc group: "Conversion"
  @spec fetch_env_boolean!(String.t(), keyword) :: boolean()
  def fetch_env_boolean!(varname, opts \\ []), do: fetch_env_as!(varname, :boolean, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value or `nil`
  if the variable is not set and a `default` is not provided.

  Prefer using `get_env_as_integer/2`.

  ### Examples

  ```elixir
  iex> Enviable.get_env_integer("UNSET")
  nil

  iex> Enviable.get_env_integer("PORT", default: 255)
  255
  ```
  """
  @doc deprecated: "Use get_env_as_integer/2 or get_env_as/3 instead"
  @doc group: "Conversion"
  @spec get_env_integer(String.t(), keyword) :: integer() | nil
  def get_env_integer(varname, opts \\ []), do: get_env_as(varname, :integer, opts)

  @doc """
  Returns the value of an environment variable as `{:ok, t:integer/0}` or `:error` if the
  variable is unset.

  Prefer using `fetch_env_as_integer/2`.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_integer("UNSET")
  :error

  iex> Enviable.put_env("PORT", "1")
  iex> Enviable.fetch_env_integer("PORT")
  {:ok, 1}
  ```
  """
  @doc deprecated: "Use fetch_env_as_integer/2 or fetch_env_as/3 instead"
  @doc group: "Conversion"
  @spec fetch_env_integer(String.t(), keyword) :: {:ok, integer()} | :error
  def fetch_env_integer(varname, opts \\ []), do: fetch_env_as(varname, :integer, opts)

  @doc """
  Returns the value of an environment variable converted to a `t:integer/0` value raises
  an exception if the variable is unset.

  Prefer using `fetch_env_as_integer!/2`.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env_integer!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("PORT", "1")
  iex> Enviable.fetch_env_integer!("PORT")
  1
  ```
  """
  @doc deprecated: "Use fetch_env_as_integer!/2 or fetch_env_as!/3 instead"
  @doc group: "Conversion"
  @spec fetch_env_integer!(String.t(), keyword) :: integer()
  def fetch_env_integer!(varname, opts \\ []), do: fetch_env_as!(varname, :integer, opts)

  @doc """
  Deletes an environment variable, removing `varname` from the environment.
  """
  @doc group: "Delegates"
  @spec delete_env(String.t()) :: :ok
  defdelegate delete_env(varname), to: System

  @doc """
  Returns the value of the given environment variable or `:error` if not found.

  If the environment variable `varname` is set, then `{:ok, value}` is returned where
  value is a string. If `varname` is not set, `:error` is returned.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env("PORT")
  :error

  iex> Enviable.put_env("PORT", "4000")
  iex> Enviable.fetch_env("PORT")
  {:ok, "4000"}
  ```
  """
  @doc group: "Delegates"
  @spec fetch_env(String.t()) :: {:ok, String.t()} | :error
  defdelegate fetch_env(varname), to: System

  @doc """
  Returns the value of the given environment variable or raises if not found.

  Same as `get_env/1` but raises instead of returning `nil` when the variable is not set.

  ### Examples

  ```elixir
  iex> Enviable.fetch_env!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> Enviable.put_env("PORT", "4000")
  iex> Enviable.fetch_env!("PORT")
  "4000"
  ```
  """
  @doc group: "Delegates"
  @spec fetch_env!(String.t()) :: String.t()
  defdelegate fetch_env!(varname), to: System

  @doc """
  Returns all system environment variables.

  The returned value is a map containing name-value pairs. Variable names and their values
  are strings.
  """
  @doc group: "Delegates"
  @spec get_env() :: %{optional(String.t()) => String.t()}
  defdelegate get_env, to: System

  @doc """
  Returns the value of the given environment variable.

  The returned value of the environment variable `varname` is a string. If the environment
  variable is not set, returns the string specified in `default` or `nil` if none is
  specified.

  ### Examples

  ```elixir
  iex> Enviable.get_env("PORT")
  nil

  iex> Enviable.get_env("PORT", "4001")
  "4001"

  iex> Enviable.put_env("PORT", "4000")
  iex> Enviable.get_env("PORT")
  "4000"
  iex> Enviable.get_env("PORT", "4001")
  "4000"
  ```
  """
  @doc group: "Delegates"
  @spec get_env(String.t(), default) :: String.t() | default
        when default: String.t() | nil
  defdelegate get_env(varname, default \\ nil), to: System

  @doc """
  Sets an environment variable value.

  Sets a new `value` for the environment variable `varname`.
  """
  @doc group: "Delegates"
  @spec put_env(String.t(), String.t()) :: :ok
  defdelegate put_env(varname, value), to: System

  @doc """
  Sets multiple environment variables.

  Sets a new value for each environment variable corresponding to each `{key, value}` pair
  in `enum`. Keys and non-nil values are automatically converted to charlists. `nil`
  values erase the given keys.

  Overall, this is a convenience wrapper around `put_env/2` and `delete_env/2` with
  support for different key and value formats.
  """
  @doc group: "Delegates"
  @spec put_env(Enumerable.t()) :: :ok
  defdelegate put_env(var_map), to: System
end
