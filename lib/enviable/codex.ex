defmodule Enviable.Codex do
  @moduledoc """
  Enviable.Codex is a small collection of functions to improve Elixir project
  configuration via environment variables as proposed under the [12-factor][12f]
  application model. It works well with configuration environment loaders like
  [Dotenvy][Dotenvy] or [Nvir][nvir] and provides robust value conversion like
  [jetenv][jetenv].

  It differs from the current `Enviable` interface by separating value retrieval from
  conversion.

  ```elixir
  port = fetch_env!("PORT") |> as_integer()
  ```

  The full Enviable conversion capabilities are present, and there are additional value
  retrieval functions that enable working with maps returned from Dotenvy or Nvir.
  Enviable.Codex retrieval functions returns a structured value with a `String.Chars`
  protocol implementation, not `String.t() | nil`.

  ### Usage

  Enviable.Codex will typically be imported in `config/runtime.exs` after `Config`, but
  may be used anywhere that environment variables are read.

  ```elixir
  # config/runtime.exs
  import Config
  import Enviable.Codex

  # The `to_string` or `as_string` is required because of the return for the imported
  # value retrieval functions.
  client = fetch_env!("CLIENT") |> to_string()

  # This side effect is required when using normal environment retrieval.
  Dotenvy.source([".env", ".env.\#{client}", get_env()], side_effect: &put_env/1)

  # Before
  #
  # config :my_app,
  #   key: System.fetch_env!("SECRET_KEY"),
  #   port: System.fetch_env!("PORT") |> String.to_integer(),
  #   ssl: System.get_env("SSL_ENABLED") in ~w[1 true]

  # After
  config :my_app,
    key: fetch_env_once!("SECRET_KEY") |> as_string(),
    port: fetch_env!("PORT") |> as_integer(),
    ssl: get_env("SSL_ENABLED") |> as_boolean()
  ```

  `fetch_env_once!/1` reads `SECRET_KEY` and removes it from the environment variable
  table. Later calls to `System.get_env/1` (or any Enviable function) and child processes
  started after will not see it. The operating system may still expose the environment
  variable (such as through `/proc/<pid>/environ` on Linux) and anything that read the
  environment variable prior to the `once` call keeps its copy.

  Both Dotenvy and Nvir will return resolved environment maps
  (`t:Enviable.Value.env_map/0`) that may be used instead of the environment variables
  (there is no `once` family of functions for map retrieval, as the maps exist only as
  long as the configuration provider).


  ```elixir
  # config/runtime.exs
  import Config
  import Enviable.Codex

  # The `to_string` or `as_string` is required because of the return for the imported
  # value retrieval functions.
  client = fetch_env!("CLIENT") |> to_string()
  {:ok, values} = Dotenvy.source([".env", ".env.\#{client}", get_env()])

  # Before
  #
  # config :my_app,
  #   key: values["SECRET_KEY"],
  #   port: values["PORT"] |> String.to_integer(),
  #   ssl: values["SSL_ENABLED"] in ~w[1 true]

  # After
  config :my_app,
    key: fetch_env_map!(values, "SECRET_KEY") |> as_string(),
    port: fetch_env_map!(values, "PORT") |> as_integer(),
    ssl: get_env_map(values, "SSL_ENABLED") |> as_boolean()
  ```

  > #### Info {: .info}
  >
  > Both Dotenvy and NVir provide `env!/2` functions that have converters. These can be
  > used, but they are narrower than the converters provided in Enviable.
  >
  > When using NVir, it automatically stores the updated values in the environment. The
  > use of the `env_map` retrieval functions is less useful when some environment
  > variables must be read exactly once.

  ### Configuration

  See [Enviable Configuration](`m:Enviable#module-configuration`).

  [12f]: https://12factor.net/
  [dotenvy]: https://hexdocs.pm/dotenvy/readme.html
  [jason]: https://hexdocs.pm/jason/readme.html
  [jetenv]: https://hexdocs.pm/jetenv/readme.html
  [jp]: https://hexdocs.pm/json_polyfill/readme.html
  [nvir]: https://hexdocs.pm/nvir/readme.html
  """
  @moduledoc since: "3.0.0"

  alias Enviable.Conversion
  alias Enviable.Conversion.Schema
  alias Enviable.Value

  @paranoid Application.compile_env(:enviable, :paranoid, false)

  @doc """
  Converts an environment variable value to the target `type` or a default value if the
  variable is unset. If no `default` is provided, `nil` is returned (unless converting to
  `:boolean`, which will return `false`).

  Supported primitive conversions are:

  - `:atom` (`t:Enviable.Conversion.convert_atom/0`, `as_atom/2`)
  - `:boolean` (`t:Enviable.Conversion.convert_boolean/0`, `as_boolean/2`)
  - `:charlist` (`t:Enviable.Conversion.convert_charlist/0`, `as_charlist/2`)
  - `:decimal` (`t:Enviable.Conversion.convert_decimal/0`, `as_decimal/2`)
  - `:duration` (`t:Enviable.Conversion.convert_duration/0`, `as_duration/2`)
  - `:elixir` (`t:Enviable.Conversion.convert_elixir/0`, `as_elixir/1`)
  - `:erlang` (`t:Enviable.Conversion.convert_erlang/0`, `as_erlang/1`)
  - `:float` (`t:Enviable.Conversion.convert_float/0`, `as_float/2`)
  - `:integer` (`t:Enviable.Conversion.convert_integer/0`, `as_integer/2`)
  - `:json` (`t:Enviable.Conversion.convert_json/0`, `as_json/2`)
  - `:log_level` (`t:Enviable.Conversion.convert_log_level/0`, `as_log_level/2`)
  - `:module` (`t:Enviable.Conversion.convert_module/0`, `as_module/2`)
  - `:pem` (`t:Enviable.Conversion.convert_pem/0`, `as_pem/2`)
  - `:safe_atom` (`t:Enviable.Conversion.convert_safe_atom/0`, `as_safe_atom/2`)
  - `:safe_module` (`t:Enviable.Conversion.convert_safe_module/0`, `as_safe_module/2`)
  - `:string` (`t:Enviable.Conversion.convert_string/0`, `as_string/2`)
  - `:timeout` (`t:Enviable.Conversion.convert_timeout/0`, `as_timeout/2`)

  Supported encoded conversions are:

  - `:base16` (`t:Enviable.Conversion.encoded_base16/0`, `as_base16/2`)
  - `:base32` (`t:Enviable.Conversion.encoded_base32/0`, `as_base32/2`)
  - `:base64`, `:url_base64` (`t:Enviable.Conversion.encoded_base64/0`, `as_base64/2`,
     `as_url_base64/2`)
  - `:hex32` (`t:Enviable.Conversion.encoded_hex32/0`, `as_hex32/2`)
  - `:list` (`t:Enviable.Conversion.encoded_list/0`, `as_list/2`)

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
  iex> get_env("UNSET") |> as(:atom)
  nil

  iex> get_env("UNSET") |> as(:float)
  nil

  iex> get_env("UNSET") |> as(:base16)
  nil

  iex> put_env("NAME", "as")
  iex> get_env("NAME") |> as(:atom)
  :as

  iex> put_env("NAME", "AS")
  iex> get_env("NAME") |> as(:safe_atom, downcase: true)
  :as

  iex> get_env("FLOAT") |> as(:float, default: "3.5")
  3.5

  iex> get_env("FLOAT") |> as(:float, default: 3.5)
  3.5

  iex> put_env("FLOAT", "3")
  iex> get_env("FLOAT") |> as(:float)
  3.0

  iex> put_env("FLOAT", "3.1")
  iex> get_env("FLOAT") |> as(:float)
  3.1

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env("NAME") |> as(:base16, case: :lower)
  "RED"
  iex> get_env("NAME") |> as({:base16, :string}, case: :lower)
  "RED"
  iex> get_env("NAME") |> as({:base16, :atom}, case: :lower, downcase: true)
  :red

  iex> put_env("LIST", "1,2,3")
  iex> get_env("LIST") |> as(:list)
  ["1", "2", "3"]
  iex> get_env("LIST") |> as({:list, :integer})
  [1, 2, 3]

  iex> put_env("LIST", "1;2;3")
  iex> get_env("LIST") |> as(:list, delimiter: ";")
  ["1", "2", "3"]
  iex> get_env("LIST") |> as({:list, :integer}, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as(Value.t(), Conversion.conversion(), keyword()) :: nil | term()
  def as(%Value{} = value, type, opts \\ []) do
    Conversion.convert_as(value, type, opts)
  end

  atom_exhaustion =
    "[Preventing atom exhaustion](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/atom_exhaustion)"

  atom_options = """
  ### Options

  #{Schema.docs(:atom)}

  A shorthand for the `default` option may be provided as a `t:atom/0` value.
  """

  @doc """
  Converts an environment variable value to `t:atom/0` or a default value if the variable
  is unset. If no `default` is provided, `nil` is returned.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_atom/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_atom()
  nil

  iex> get_env("UNSET") |> as_atom(:default)
  :default

  iex> get_env("UNSET") |> as_atom(default: :default)
  :default

  iex> put_env("NAME", "as_atom")
  iex> get_env("NAME") |> as_atom()
  :as_atom
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_atom(
          Value.t(),
          atom() | String.t() | [unquote(Schema.option_typespec(:atom))]
        ) :: nil | atom()
  def as_atom(value, opts \\ [])

  def as_atom(value, default) when is_atom(default) or is_binary(default), do: as(value, :atom, default: default)

  def as_atom(value, opts), do: as(value, :atom, opts)

  @doc """
  Converts an environment variable value to an existing `t:atom/0` or a default value if
  the variable is unset. If no `default` is provided, `nil` is returned.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `String.to_existing_atom/1` which will result in an
  > exception if the resulting atom is not already known and if used without the
  > `:allowed` option. See #{atom_exhaustion} from the Security Working Group of the
  > Erlang Ecosystem Foundation.

  #{atom_options}

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_safe_atom()
  nil

  iex> get_env("UNSET") |> as_safe_atom(:default)
  :default

  iex> get_env("UNSET") |> as_safe_atom(default: :default)
  :default

  iex> put_env("NAME", "AS_SAFE_ATOM")
  iex> get_env("NAME") |> as_safe_atom(downcase: true)
  :as_safe_atom
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_safe_atom(
          Value.t(),
          atom() | String.t() | [unquote(Schema.option_typespec(:safe_atom))]
        ) :: nil | atom()
  def as_safe_atom(value, opts \\ [])

  def as_safe_atom(value, default) when is_atom(default) or is_binary(default),
    do: as(value, :safe_atom, default: default)

  def as_safe_atom(value, opts), do: as(value, :safe_atom, opts)

  @doc """
  Converts an environment variable value to a `t:boolean/0` value, or a default value if
  the variable is unset. If no `default` is provided, `false` will be returned.

  This function always returns a `t:boolean/0` value. Unless configured with `truthy` or
  `falsy`, only the values `"1"` and `"true"` will be converted to `true` and any other
  value will result in `false`.

  ### Options

  #{Schema.docs(:boolean)}

  A shorthand value for the `default` option may be provided as a `t:boolean/0` value.

  ### Examples

  ```elixir
  iex> get_env("FLAG") |> as_boolean()
  false

  iex> get_env("FLAG") |> as_boolean(true)
  true

  iex> get_env("FLAG") |> as_boolean(default: true)
  true

  iex> put_env("FLAG", "1")
  iex> get_env("FLAG") |> as_boolean()
  true

  iex> put_env("FLAG", "something")
  iex> get_env("FLAG") |> as_boolean()
  false

  iex> put_env("FLAG", "oui")
  iex> get_env("FLAG") |> as_boolean(truthy: ["oui"])
  true

  iex> put_env("FLAG", "OUI")
  iex> get_env("FLAG") |> as_boolean(truthy: ["oui"])
  true
  iex> get_env("FLAG") |> as_boolean(truthy: ["oui"], downcase: false)
  false

  iex> put_env("FLAG", "NON")
  iex> get_env("FLAG") |> as_boolean(falsy: ["non"])
  false
  iex> get_env("FLAG") |> as_boolean(falsy: ["non"], downcase: false)
  true

  iex> get_env("FLAG") |> as_boolean(default: nil)
  ** (Enviable.OptionError) could not convert environment variable "FLAG" to type boolean: invalid `:default` value (expected boolean)

  iex> get_env("FLAG") |> as_boolean(downcase: nil)
  ** (Enviable.OptionError) could not convert environment variable "FLAG" to type boolean: invalid `:downcase` value (expected boolean or one of :default, :ascii, :greek, :turkic)

  iex> get_env("FLAG") |> as_boolean(truthy: ["oui"], falsy: ["non"])
  ** (Enviable.OptionError) could not convert environment variable "FLAG" to type boolean: `:truthy` and `:falsy` are mutually exclusive
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_boolean(
          Value.t(),
          boolean() | [unquote(Schema.option_typespec(:boolean))]
        ) :: boolean()
  def as_boolean(value, opts \\ [])
  def as_boolean(value, default) when is_boolean(default), do: as(value, :boolean, default: default)
  def as_boolean(value, opts), do: as(value, :boolean, opts)

  @doc """
  Converts an environment variable value to a `t:charlist/0` or a default value if the
  variable is unset. If no `default` is provided, `nil` is returned.

  ### Options

  #{Schema.docs(:charlist)}

  A shorthand for the `default` value may be provided as a `t:binary/0` (there is no guard for `t:charlist/0`).

  ### Examples

  ```elixir
  iex> get_env("UNDEFINED") |> as_charlist()
  nil

  iex> get_env("UNDEFINED") |> as_charlist("default")
  ~c"default"

  iex> get_env("UNDEFINED") |> as_charlist(default: "default")
  ~c"default"

  iex> get_env("UNDEFINED") |> as_charlist(default: ~c"default")
  ~c"default"

  iex> put_env("NAME", "as")
  iex> get_env("NAME") |> as_charlist()
  ~c"as"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_charlist(
          Value.t(),
          String.t() | [unquote(Schema.option_typespec(:charlist))]
        ) :: nil | charlist()
  def as_charlist(value, opts \\ [])
  def as_charlist(value, default) when is_binary(default), do: as(value, :charlist, default: default)
  def as_charlist(value, opts), do: as(value, :charlist, opts)

  @doc """
  Returns the value as a `t:String.t/0` or a default value if the variable is unset. If
  no `default` is provided, `nil` is returned.

  ### Options

  #{Schema.docs(:string)}

  A shorthand for the `default` value may be provided as a `t:String.t/0`.

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_string()
  nil

  iex> get_env("UNSET") |> as_string("default")
  "default"

  iex> get_env("UNSET") |> as_string(default: "default")
  "default"

  iex> put_env("NAME", "value")
  iex> get_env("NAME") |> as_string()
  "value"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_string(Value.t(), String.t() | [unquote(Schema.option_typespec(:string))]) :: nil | String.t()
  def as_string(value, opts \\ [])
  def as_string(value, default) when is_binary(default), do: as(value, :string, default: default)
  def as_string(value, opts), do: as(value, :string, opts)

  @doc """
  Converts an environment variable value to a `t:integer/0` value or a default value if
  the variable is unset. If no `default` is provided, `nil` is returned.

  ### Options

  #{Schema.docs(:integer)}

  A shorthand for the `default` value may be provided as a `t:integer/0` or `t:binary/0` value.

  Failure to parse a binary string `default` or the value of the environment variable will result in an exception.

  ### Examples

  ```elixir
  iex> get_env("PORT") |> as_integer()
  nil

  iex> get_env("PORT") |> as_integer(5432)
  5432

  iex> get_env("PORT") |> as_integer("5432")
  5432

  iex> get_env("PORT") |> as_integer(default: 5432)
  5432

  iex> get_env("PORT") |> as_integer(default: "5432")
  5432

  iex> get_env("PORT") |> as_integer(default: 3.5)
  ** (Enviable.OptionError) could not convert environment variable "PORT" to type integer: invalid `:default` value (expected integer or string)

  iex> put_env("PORT", "5432")
  iex> get_env("PORT") |> as_integer()
  5432

  iex> put_env("PORT", "18eb")
  iex> get_env("PORT") |> as_integer()
  ** (Enviable.ConversionError) could not convert environment variable "PORT" to type integer

  iex> put_env("PORT", "18EB")
  iex> get_env("PORT") |> as_integer(base: 16)
  6379
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_integer(
          Value.t(),
          integer() | String.t() | [unquote(Schema.option_typespec(:integer))]
        ) :: integer() | nil
  def as_integer(value, opts \\ [])

  def as_integer(value, default) when is_binary(default) or is_integer(default),
    do: as(value, :integer, default: default)

  def as_integer(value, opts), do: as(value, :integer, opts)

  @doc """
  Converts an environment variable value to a `t:float/0` value or a default value if the
  variable is unset. If no `default` is provided, `nil` will be returned.

  ### Options

  #{Schema.docs(:float)}

  A shorthand for the `default` value may be provided as a `t:float/0`, `t:integer/0`, or `t:binary/0` value.

  ### Examples

  ```elixir
  iex> get_env("FLOAT") |> as_float()
  nil

  iex> get_env("FLOAT") |> as_float(25.5)
  25.5

  iex> get_env("FLOAT") |> as_float(25)
  25.0

  iex> get_env("FLOAT") |> as_float("255")
  255.0

  iex> get_env("FLOAT") |> as_float(default: 25.5)
  25.5

  iex> get_env("FLOAT") |> as_float(default: 25)
  25.0

  iex> get_env("FLOAT") |> as_float(default: "255")
  255.0

  iex> get_env("FLOAT") |> as_float(default: "3.5R")
  ** (Enviable.OptionError) could not convert environment variable "FLOAT" to type float: `:default` is not a valid float

  iex> put_env("FLOAT", "1")
  iex> get_env("FLOAT") |> as_float()
  1.0

  iex> put_env("FLOAT", "ff")
  iex> get_env("FLOAT") |> as_float()
  ** (Enviable.ConversionError) could not convert environment variable "FLOAT" to type float
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_float(
          Value.t(),
          float() | integer() | String.t() | [unquote(Schema.option_typespec(:float))]
        ) :: float() | nil
  def as_float(value, opts \\ [])

  def as_float(value, default) when is_binary(default) or is_float(default) or is_integer(default),
    do: as(value, :float, default: default)

  def as_float(value, opts), do: as(value, :float, opts)

  @doc """
  Converts an environment variable value to a `t:Enviable.Conversion.json/0` value or
  a default value if the variable is unset. If no `default` is provided, `nil` will be
  returned.

  ### Options

  #{Schema.docs(:json)}

  ### Examples

  ```elixir
  iex> get_env("JSON") |> as_json()
  nil

  iex> get_env("JSON") |> as_json(default: "3.5R")
  "3.5R"

  iex> put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> get_env("JSON") |> as_json(engine: &Jason.decode!/1)
  [%{"foo" => "bar"}]

  iex> put_env("JSON", ~S|[{"foo":"bar"}]|)
  iex> get_env("JSON") |> as_json()
  [%{"foo" => "bar"}]

  iex> put_env("JSON", "ff")
  iex> get_env("JSON") |> as_json()
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json

  iex> put_env("JSON", "ff")
  iex> get_env("JSON") |> as_json(engine: &Jason.decode!/1)
  ** (Enviable.ConversionError) could not convert environment variable "JSON" to type json
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_json(
          Value.t(),
          [unquote(Schema.option_typespec(:json))]
        ) :: Conversion.json() | nil
  def as_json(value, opts \\ []) do
    as(value, :json, opts)
  end

  module_options = """
  ### Options

  #{Schema.docs(:module)}

  A shorthand for the `default` option may be provided as a `t:atom/0` or `t:binary/0` value.
  """

  @doc """
  Converts an environment variable value to `t:module/0` or a default value if the
  variable is unset. If no `default` is provided, `nil` will be returned.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.concat/1` and may result in atom exhaustion if
  > used without the `:allowed` option. See #{atom_exhaustion} from the Security Working
  > Group of the Erlang Ecosystem Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_module()
  nil

  iex> get_env("UNSET") |> as_module(Enviable)
  Elixir.Enviable

  iex> put_env("NAME", "Enviable")
  iex> get_env("NAME") |> as_module()
  Elixir.Enviable
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_module(
          Value.t(),
          module() | String.t() | [unquote(Schema.option_typespec(:module))]
        ) :: nil | module()
  def as_module(value, opts \\ [])
  def as_module(value, default) when is_binary(default) or is_atom(default), do: as(value, :module, default: default)
  def as_module(value, opts), do: as(value, :module, opts)

  @doc """
  Converts an environment variable value to `t:module/0` or a default value if the
  variable is unset. If no `default` is provided, `nil` will be returned. The resulting
  `t:module/0` must already exist.

  > #### Untrusted Input {: .warning}
  >
  > This conversion routine uses `Module.safe_concat/1` which will result in an exception
  > if the resulting module is not already known and if used without the `:allowed`
  > option. See #{atom_exhaustion} from the Security Working Group of the Erlang Ecosystem
  > Foundation.

  #{module_options}

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_safe_module()
  nil

  iex> get_env("UNSET") |> as_safe_module(Enviable)
  Elixir.Enviable

  iex> put_env("NAME", "Enviable")
  iex> get_env("NAME") |> as_safe_module()
  Elixir.Enviable
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_safe_module(
          Value.t(),
          module() | String.t() | [unquote(Schema.option_typespec(:safe_module))]
        ) :: nil | module()
  def as_safe_module(value, opts \\ [])

  def as_safe_module(value, default) when is_binary(default) or is_atom(default),
    do: as(value, :safe_module, default: default)

  def as_safe_module(value, opts), do: as(value, :safe_module, opts)

  @doc """
  Converts an environment variable value to a log level `t:atom/0` for
  `Logger.configure/1` or a default value if the variable is unset. If no `default` is
  provided, `nil` will be returned.

  ### Options

  #{Schema.docs(:log_level)}

  A shorthand for the `default` option may be provided as a `t:atom/0` or `t:binary/0` value.

  ### Examples

  ```elixir
  iex> get_env("LOG_LEVEL") |> as_log_level()
  nil

  iex> get_env("LOG_LEVEL") |> as_log_level(:error)
  :error

  iex> get_env("LOG_LEVEL") |> as_log_level("info")
  :info

  iex> get_env("LOG_LEVEL") |> as_log_level(default: :error)
  :error

  iex> get_env("LOG_LEVEL") |> as_log_level(default: "info")
  :info

  iex> put_env("LOG_LEVEL", "critical")
  iex> get_env("LOG_LEVEL") |> as_log_level()
  :critical
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_log_level(
          Value.t(),
          Conversion.log_level() | String.t() | [unquote(Schema.option_typespec(:log_level))]
        ) :: nil | Conversion.log_level()
  def as_log_level(value, opts \\ [])

  def as_log_level(value, default) when is_binary(default) or is_atom(default),
    do: as(value, :log_level, default: default)

  def as_log_level(value, opts), do: as(value, :log_level, opts)

  @doc """
  Converts an environment variable value from a PEM string through
  `:public_key.pem_decode/1` or `nil` if the variable is unset.

  ### Options

  #{Schema.docs(:pem)}

  ### Examples

  ```elixir
  iex> get_env("PEM") |> as_pem()
  nil

  iex> put_env("PEM", "")
  iex> get_env("PEM") |> as_pem()
  []
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_pem(
          Value.t(),
          [unquote(Schema.option_typespec(:pem))]
        ) :: nil | Conversion.pem()
  def as_pem(value, opts \\ []) do
    as(value, :pem, opts)
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
  iex> get_env("TERM") |> as_erlang()
  nil

  iex> put_env("TERM", "{ok, true}.")
  iex> get_env("TERM") |> as_erlang()
  {:ok, true}
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_erlang(Value.t()) :: nil | term()
  def as_erlang(value) do
    as(value, :erlang, [])
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
  iex> get_env("TERM") |> as_elixir()
  nil

  iex> put_env("TERM", "11000..11100//3")
  iex> get_env("TERM") |> as_elixir()
  11000..11100//3
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_elixir(Value.t()) :: nil | term()
  def as_elixir(value) do
    as(value, :elixir, [])
  end

  @doc """
  Returns the value of an environment variable decoded from a base 16 string or `nil` if
  the environment variable is not set.

  ## Options

  #{Schema.docs(:base16, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env("NAME") |> as_base16()
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env("NAME") |> as_base16(case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env("NAME") |> as_base16(as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode16("RED", case: :lower))
  iex> get_env("NAME") |> as_base16(as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_base16(
          Value.t(),
          [unquote(Schema.option_typespec(:base16, as: :encoded))]
        ) :: nil | term()
  def as_base16(value, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base16, opts}
        {type, opts} -> {{:base16, type}, opts}
      end

    as(value, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 string or `nil` if
  the environment variable is not set.

  ## Options

  #{Schema.docs(:base32, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_base32()
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_base32(case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_base32(as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_base32(as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_base32(
          Value.t(),
          [unquote(Schema.option_typespec(:base32, as: :encoded))]
        ) :: nil | term()
  def as_base32(value, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base32, opts}
        {type, opts} -> {{:base32, type}, opts}
      end

    as(value, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 32 hex encoded string
  or `nil` if the environment variable is not set.

  ## Options

  #{Schema.docs(:hex32, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_hex32()
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_hex32(case: :lower)
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_hex32(as: :string, case: :lower)
  "RED"

  iex> put_env("NAME", Base.hex_encode32("RED", case: :lower))
  iex> get_env("NAME") |> as_hex32(as: :atom, case: :lower, downcase: true)
  :red
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_hex32(
          Value.t(),
          [unquote(Schema.option_typespec(:hex32, as: :encoded))]
        ) :: nil | term()
  def as_hex32(value, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:hex32, opts}
        {type, opts} -> {{:hex32, type}, opts}
      end

    as(value, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a base 64 string or `nil` if
  the environment variable is not set.

  ## Options

  #{Schema.docs(:base64, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env("NAME") |> as_base64()
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env("NAME") |> as_base64(padding: false)
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env("NAME") |> as_base64(as: :string, padding: true)
  "RED"

  iex> put_env("NAME", Base.encode64("RED", padding: true))
  iex> get_env("NAME") |> as_base64(as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_base64(
          Value.t(),
          [unquote(Schema.option_typespec(:base64, as: :encoded))]
        ) :: nil | term()
  def as_base64(value, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:base64, opts}
        {type, opts} -> {{:base64, type}, opts}
      end

    as(value, type, opts)
  end

  @doc """
  Returns the value of an environment variable decoded from a URL-safe base 64 string or
  `nil` if the environment variable is not set.

  ## Options

  #{Schema.docs(:url_base64, as: :encoded)}

  ### Examples

  ```elixir
  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env("NAME") |> as_url_base64()
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env("NAME") |> as_url_base64(padding: false)
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env("NAME") |> as_url_base64(as: :string, padding: true)
  "RED"

  iex> put_env("NAME", Base.url_encode64("RED", padding: true))
  iex> get_env("NAME") |> as_url_base64(as: :atom, downcase: true, padding: false)
  :red
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_url_base64(
          Value.t(),
          [unquote(Schema.option_typespec(:url_base64, as: :encoded))]
        ) :: nil | term()
  def as_url_base64(value, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:url_base64, opts}
        {type, opts} -> {{:url_base64, type}, opts}
      end

    as(value, type, opts)
  end

  @doc """
  Returns the value of an environment variable parsed as a delimiter-separated list.

  ## Options

  #{Schema.docs(:list, as: :list)}

  ### Examples

  ```elixir
  iex> put_env("LIST", "1,2,3")
  iex> get_env("LIST") |> as_list()
  ["1", "2", "3"]
  iex> get_env("LIST") |> as_list(as: :integer)
  [1, 2, 3]

  iex> put_env("LIST", "1;2;3")
  iex> get_env("LIST") |> as_list(delimiter: ";")
  ["1", "2", "3"]
  iex> get_env("LIST") |> as_list(as: :integer, delimiter: ";")
  [1, 2, 3]
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_list(
          Value.t(),
          [Conversion.as_list_opt()]
        ) :: nil | list()
  def as_list(value, opts \\ []) do
    {type, opts} =
      case Keyword.pop(opts, :as) do
        {nil, opts} -> {:list, opts}
        {type, opts} -> {{:list, type}, opts}
      end

    as(value, type, opts)
  end

  if Code.ensure_loaded?(Decimal) do
    @doc """
    Converts an environment variable value to a `t:Decimal.t/0` value or a default value
    if the variable is unset. If no `default` is provided, `nil` will be returned.

    ### Options

    #{Schema.docs(:decimal)}

    A shorthand for the `default` value may be provided as a `t:Decimal.t/0`, `t:float/0`, `t:integer/0`, or `t:binary/0` value.

    ### Examples

    ```elixir
    iex> get_env("DECIMAL") |> as_decimal()
    nil

    iex> get_env("DECIMAL") |> as_decimal(Decimal.new("3.14"))
    Decimal.new("3.14")

    iex> get_env("DECIMAL") |> as_decimal(25.5)
    Decimal.new("25.5")

    iex> get_env("DECIMAL") |> as_decimal(25)
    Decimal.new("25")

    iex> get_env("DECIMAL") |> as_decimal("255")
    Decimal.new("255")

    iex> get_env("DECIMAL") |> as_decimal(default: Decimal.new("3.14"))
    Decimal.new("3.14")

    iex> get_env("DECIMAL") |> as_decimal(default: 25.5)
    Decimal.new("25.5")

    iex> get_env("DECIMAL") |> as_decimal(default: 25)
    Decimal.new("25")

    iex> get_env("DECIMAL") |> as_decimal(default: "255")
    Decimal.new("255")

    iex> get_env("DECIMAL") |> as_decimal(default: "3.5R")
    ** (Enviable.OptionError) could not convert environment variable "DECIMAL" to type decimal: `:default` is not a valid decimal

    iex> get_env("DECIMAL") |> as_decimal(default: %{})
    ** (Enviable.OptionError) could not convert environment variable "DECIMAL" to type decimal: invalid `:default` value (expected Decimal, float, integer, or string)

    iex> put_env("DECIMAL", "1")
    iex> get_env("DECIMAL") |> as_decimal()
    Decimal.new("1")

    iex> put_env("DECIMAL", "ff")
    iex> get_env("DECIMAL") |> as_decimal()
    ** (Enviable.ConversionError) could not convert environment variable "DECIMAL" to type decimal
    ```
    """
    @doc since: "3.0.0"
    @doc group: "Conversion"
    @spec as_decimal(
            Value.t(),
            Decimal.t() | float() | integer() | String.t() | [unquote(Schema.option_typespec(:decimal))]
          ) :: Decimal.t() | nil
    def as_decimal(value, opts \\ [])

    def as_decimal(value, default)
        when is_binary(default) or is_float(default) or is_integer(default) or is_struct(default, Decimal),
        do: as(value, :decimal, default: default)

    def as_decimal(value, opts), do: as(value, :decimal, opts)
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
  Converts an environment variable value to a millisecond `t:timeout/0` or a default value
  if the variable is unset. If no `default` is provided, `:infinity` will be returned.

  #{timeout_values}

  ### Options

  #{Schema.docs(:timeout)}

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_timeout()
  :infinity

  iex> get_env("UNSET") |> as_timeout("30s")
  30000

  iex> get_env("UNSET") |> as_timeout("PT30S")
  30000

  iex> put_env("TIMEOUT", "3_0 seconds")
  iex> get_env("TIMEOUT") |> as_timeout()
  30000

  iex> put_env("TIMEOUT", "PT30S")
  iex> get_env("TIMEOUT") |> as_timeout()
  30000

  iex> get_env("UNSET") |> as_timeout(hour: 1, minute: 30)
  5400000

  iex> get_env("UNSET") |> as_timeout(default: [hour: 1, minute: 30])
  5400000
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_timeout(
          Value.t(),
          timeout()
          | String.t()
          | Duration.t()
          | [unquote(Schema.option_typespec(:timeout)) | {Conversion.timeout_unit(), non_neg_integer()}]
        ) :: timeout()
  def as_timeout(value, opts \\ [])

  def as_timeout(value, default)
      when (is_integer(default) and default >= 0) or default == :infinity or is_binary(default) or
             is_struct(default, Duration), do: as(value, :timeout, default: default)

  def as_timeout(value, []), do: as(value, :timeout, [])

  def as_timeout(value, opts) do
    opts =
      case Keyword.validate(opts, [:week, :day, :hour, :minute, :second, :millisecond]) do
        {:ok, _} -> [default: opts]
        {:error, _} -> opts
      end

    as(value, :timeout, opts)
  end

  @doc """
  Converts an environment variable value to a `t:Duration.t/0` or a default value if the
  variable is unset. If no `default` is provided, `nil` will be returned.

  #{timeout_values}

  ### Options

  #{Schema.docs(:duration)}

  ### Examples

  ```elixir
  iex> get_env("UNSET") |> as_duration()
  nil

  iex> get_env("UNSET") |> as_duration("PT30S")
  %Duration{second: 30}

  iex> put_env("TIMEOUT", "PT1H30M")
  iex> get_env("TIMEOUT") |> as_duration()
  %Duration{hour: 1, minute: 30}
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Conversion"
  @spec as_duration(
          Value.t(),
          String.t() | Duration.t() | [unquote(Schema.option_typespec(:duration))]
        ) :: Duration.t()
  def as_duration(value, opts \\ [])

  def as_duration(value, default) when is_struct(default, Duration) or is_binary(default),
    do: as(value, :duration, default: default)

  def as_duration(value, opts), do: as(value, :duration, opts)

  @doc """
  Returns `true` if the `t:Value.t/0` is set (its inner value is not `nil`).
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec set?(Value.t()) :: boolean()
  defdelegate set?(value), to: Value

  @doc """
  Returns `true` if the `t:Value.t/0` is unset (its inner value is `nil`).
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec unset?(Value.t()) :: boolean()
  defdelegate unset?(value), to: Value

  @doc """
  Returns `true` if the `t:Value.t/0` is secure (its inner value is set and wrapped by
  a closure).

  ### Examples

  ```elixir
  iex> secure?(%Enviable.Value{name: "PORT", value: "4000"})
  false
  iex> put_env("PORT", "4000")
  iex> fetch_env_once!("PORT") |> secure?()
  true
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec secure?(Value.t()) :: boolean()
  defdelegate secure?(value), to: Value

  @doc """
  If the Value is set and not a secure value, makes it secure by wrapping its inner value
  in a closure.

  ### Examples

  ```elixir
  iex> value = secure(%Enviable.Value{name: "PORT", value: "4000"})
  iex> secure?(value)
  true
  iex> to_string(value)
  "4000"
  iex> unset = secure(%Enviable.Value{name: "UNSET", value: nil})
  iex> secure?(unset)
  false
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec secure(Value.t()) :: Value.t()
  defdelegate secure(value), to: Value

  @doc """
  Deletes an environment variable, removing it from the environment. A `t:Value.t/0`
  deletes the variable with the Value's name.

  ### Examples

  ```elixir
  iex> put_env("PORT", "4000")
  iex> delete_env("PORT")
  :ok
  iex> fetch_env("PORT")
  :error

  iex> put_env("PORT", "4000")
  iex> delete_env(%Enviable.Value{name: "PORT", value: nil})
  :ok
  iex> fetch_env("PORT")
  :error
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec delete_env(String.t() | Value.t()) :: :ok
  def delete_env(%Value{name: name}), do: System.delete_env(name)
  def delete_env(name), do: System.delete_env(name)

  @doc """
  Returns the `t:Value.t/0` of the given environment variable or `:error` if not found.

  If the environment variable is set, then `{:ok, value}` is returned where Value contains
  a string. If it is not set, `:error` is returned.

  ### Examples

  ```elixir
  iex> fetch_env("PORT")
  :error

  iex> put_env("PORT", "4000")
  iex> {:ok, value} = Enviable.Codex.fetch_env("PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :env, ...>
  iex> to_string(value)
  "4000"

  iex> put_env("PORT", "4000")
  iex> {:ok, value} = Enviable.Codex.fetch_env(%Enviable.Value{name: "PORT", value: nil})
  iex> to_string(value)
  "4000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec fetch_env(String.t() | Value.t()) :: {:ok, Value.t()} | :error
  def fetch_env(%Value{name: name}), do: fetch_env(name)

  def fetch_env(name) do
    case System.fetch_env(name) do
      {:ok, value} -> {:ok, secure_if_paranoid(name, value, :env)}
      :error -> :error
    end
  end

  @doc """
  Returns the `t:Value.t/0` value of the given environment variable or raises if not
  found. Same as `get_env/1` but raises instead of returning an `t:Value.t/0` which is
  `unset?/1`.

  ### Examples

  ```elixir
  iex> fetch_env!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("PORT", "4000")
  iex> value = Enviable.Codex.fetch_env!("PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :env, ...>
  iex> to_string(value)
  "4000"
  iex> fetch_env!(%Enviable.Value{name: "PORT", value: nil}) |> to_string()
  "4000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec fetch_env!(String.t() | Value.t()) :: Value.t()
  def fetch_env!(%Value{name: name}), do: fetch_env!(name)

  def fetch_env!(name) do
    secure_if_paranoid(name, System.fetch_env!(name), :env)
  end

  @doc """
  Returns the `t:Value.t/0` of the given environment variable or `:error` if not found.
  The environment variable is erased after retrieval.

  If the environment variable is set, then `{:ok, value}` is returned where Value contains
  a string. If it is not set, `:error` is returned.

  ### Examples

  ```elixir
  iex> put_env("PORT", "4000")
  iex> {:ok, value} = Enviable.Codex.fetch_env_once("PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :env, ...>
  iex> to_string(value)
  "4000"
  iex> fetch_env_once("PORT")
  :error

  iex> put_env("PORT", "4000")
  iex> {:ok, value} = Enviable.Codex.fetch_env_once(%Enviable.Value{name: "PORT", value: nil})
  iex> to_string(value)
  "4000"
  iex> fetch_env_once("PORT")
  :error
  iex> as_integer(value)
  4000
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec fetch_env_once(String.t() | Value.t()) :: {:ok, Value.t()} | :error
  def fetch_env_once(%Value{name: name}), do: fetch_env_once(name)

  def fetch_env_once(name) do
    case System.fetch_env(name) do
      {:ok, value} ->
        delete_env(name)
        {:ok, secure(%Value{name: name, value: value, source: :env})}

      :error ->
        :error
    end
  end

  @doc """
  Returns the `t:Value.t/0` value of the given environment variable or raises if not
  found. Same as `fetch_env_once/1` but raises instead of returning `:error` when the
  variable is not set. The environment variable is erased after retrieval.

  ### Examples

  ```elixir
  iex> fetch_env_once!("UNSET")
  ** (System.EnvError) could not fetch environment variable "UNSET" because it is not set

  iex> put_env("PORT", "4000")
  iex> value = Enviable.Codex.fetch_env_once!("PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :env, ...>
  iex> to_string(value)
  "4000"
  iex> fetch_env_once!("PORT")
  ** (System.EnvError) could not fetch environment variable "PORT" because it is not set

  iex> put_env("PORT", "4000")
  iex> fetch_env_once!(%Enviable.Value{name: "PORT", value: nil}) |> to_string()
  "4000"
  iex> fetch_env_once("PORT")
  :error
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec fetch_env_once!(String.t() | Value.t()) :: Value.t()
  def fetch_env_once!(%Value{name: name}), do: fetch_env_once!(name)

  def fetch_env_once!(name) do
    value = System.fetch_env!(name)
    delete_env(name)
    secure(%Value{name: name, source: :env, value: value})
  end

  @doc """
  Returns all system environment variables.

  The returned value is a map containing name-value pairs. Variable names and their values
  are both strings (not `t:Value.t/0`).
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec get_env() :: Value.env_map()
  defdelegate get_env, to: System

  @doc """
  Returns the `t:Value.t/0` of the given environment variable or the default value if
  provided.

  A `t:Value.t/0` may be provided as the name (its inner value is the default) or as the
  default (its inner value is used). When both a `t:Value.t/0` name and `default` are
  provided, the `default` takes precedence.

  ### Examples

  ```elixir
  iex> get_env("PORT") |> Enviable.Codex.unset?()
  true

  iex> get_env("PORT", "4000") |> to_string()
  "4000"

  iex> get_env("PORT", %Enviable.Value{name: "OTHER", value: "4000"}) |> to_string()
  "4000"

  iex> value = %Enviable.Value{name: "PORT", value: "4000"}
  iex> get_env(value) |> to_string()
  "4000"
  iex> get_env(value, "4001") |> to_string()
  "4001"
  iex> put_env("PORT", "4002")
  iex> get_env(value, "4001") |> to_string()
  "4002"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec get_env(String.t() | Value.t(), nil | String.t() | Value.t()) :: Value.t()
  def get_env(name_or_value, default \\ nil)

  def get_env(name_or_value, %Value{} = default) do
    value = get_env(name_or_value, nil)

    if set?(value) do
      value
    else
      %{value | value: default.value}
    end
  end

  def get_env(%Value{} = value, nil) do
    get_env(value.name, value)
  end

  def get_env(%Value{} = value, default) do
    get_env(value.name, default)
  end

  def get_env(name, default) do
    secure_if_paranoid(name, System.get_env(name, default), :env)
  end

  @doc """
  Returns the `t:Value.t/0` of the given environment variable. The environment variable
  is erased after retrieval.

  Defaults behave as they do for `get_env/2`. When both a `t:Value.t/0` name and
  `default` are provided, the `default` takes precedence.

  ### Examples

  ```elixir
  iex> put_env("PORT", "4000")
  iex> get_env_once("PORT") |> to_string()
  "4000"
  iex> fetch_env("PORT")
  :error

  iex> get_env_once("PORT") |> Enviable.Codex.unset?()
  true

  iex> get_env_once("PORT", "4001") |> to_string()
  "4001"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec get_env_once(String.t() | Value.t(), nil | String.t() | Value.t()) :: Value.t()
  def get_env_once(name_or_value, default \\ nil) do
    value = get_env(name_or_value, default)
    delete_env(value)
    secure(value)
  end

  @doc """
  Sets or deletes a single environment variable. If the value is a `t:String.t/0` or is
  `set?/1`, the environment variable is updated. If the value is `nil` or `unset?/1`, the
  environment variable is deleted. (`System.put_env/2` raises on `nil`.)

  ### Examples

  ```elixir
  iex> put_env("PORT", "4000")
  :ok
  iex> get_env("PORT") |> to_string()
  "4000"
  iex> put_env("PORT", nil)
  :ok
  iex> get_env("PORT") |> Enviable.Codex.set?()
  false

  iex> put_env("PORT", %Enviable.Value{name: "IGNORED", value: "4001"})
  iex> get_env("PORT") |> to_string()
  "4001"

  iex> put_env("PORT", "4003")
  iex> put_env("PORT", %Enviable.Value{name: "PORT", value: nil})
  iex> get_env("PORT") |> Enviable.Codex.set?()
  false
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec put_env(name :: String.t() | Value.t(), value :: nil | String.t() | Value.t()) :: :ok
  def put_env(%Value{name: name}, value), do: put_env(name, value)
  def put_env(name, %Value{value: nil}), do: delete_env(name)
  def put_env(name, %Value{} = value), do: put_env(name, Value.__unwrap__(value))
  def put_env(name, nil), do: delete_env(name)
  def put_env(name, value), do: System.put_env(name, value)

  @doc """
  Sets one or more environment variables.

  Sets new values for each environment variable corresponding to the `t:Value.t/0` or
  `{key, value}` pair in `enum`. Keys and non-`nil` values are automatically converted to
  charlists. `nil` values erase the given keys.

  A single `t:Value.t/0` is set (when the value is `set?/1`) or erased (when the value is
  `unset?/1`).

  ### Examples

  ```elixir
  iex> put_env(%Enviable.Value{name: "PORT", value: "4002"})
  iex> get_env("PORT") |> to_string()
  "4002"
  iex> put_env(%Enviable.Value{name: "PORT", value: nil})
  iex> fetch_env("PORT")
  :error
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec put_env(Value.t() | Enumerable.t()) :: :ok
  def put_env(%Value{name: name, value: nil}), do: delete_env(name)
  def put_env(%Value{} = value), do: put_env(value.name, Value.__unwrap__(value))

  def put_env(enum) do
    Enum.each(enum, fn
      %Value{name: key, value: nil} -> os_unsetenv(key)
      %Value{name: key, value: val} -> os_putenv(key, val)
      {key, nil} -> os_unsetenv(key)
      {key, val} -> os_putenv(key, val)
    end)
  end

  @doc """
  Set an environment variable `t:Value.t/0` only if it is not yet set.

  This is a safe wrapper around `get_env/2` piped into `put_env/1`: the current
  environment value (if any) wins over the `t:Value.t/0`'s inner value, which is used
  only as the default. If the resolved value is `nil`, the variable is erased.

  ### Examples

  ```elixir
  iex> put_env_new(%Enviable.Value{name: "PORT", value: "3000"})
  :ok
  iex> value = Enviable.Codex.get_env("PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :env, ...>
  iex> to_string(value)
  "3000"
  iex> put_env_new(%{value | value: "5000"})
  :ok
  iex> get_env("PORT") |> to_string()
  "3000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec put_env_new(Value.t()) :: :ok
  def put_env_new(%Value{} = value) do
    value
    |> get_env()
    |> put_env()
  end

  @doc """
  Set an environment variable value only if it is not yet set. This is a convenience
  wrapper around `get_env/2` and `put_env/1`.

  ### Examples

  ```elixir
  iex> put_env_new("PORT", "3000")
  :ok
  iex> get_env("PORT") |> to_string()
  "3000"
  iex> put_env_new("PORT", "5000")
  :ok
  iex> get_env("PORT") |> to_string()
  "3000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "Env"
  @spec put_env_new(String.t() | Value.t(), String.t() | Value.t()) :: :ok
  def put_env_new(name, value) do
    put_env(get_env(name, value))
  end

  # ---

  @doc """
  Returns the `t:Value.t/0` of the variable from the `t:Value.env_map/0` or `:error` if
  not found.

  If the variable is set, then `{:ok, value}` is returned where Value contains a string.
  If it is not set, `:error` is returned.

  ### Examples

  ```elixir
  iex> fetch_env_map(%{}, "PORT")
  :error

  iex> {:ok, value} = Enviable.Codex.fetch_env_map(%{"PORT" => "4000"}, "PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :map, ...>
  iex> to_string(value)
  "4000"

  iex> name = %Enviable.Value{name: "PORT", value: nil}
  iex> {:ok, value} = Enviable.Codex.fetch_env_map(%{"PORT" => "4000"}, name)
  iex> to_string(value)
  "4000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "EnvMap"
  @spec fetch_env_map(Value.env_map(), String.t() | Value.t()) :: {:ok, Value.t()} | :error
  def fetch_env_map(map, %Value{name: name}), do: fetch_env_map(map, name)

  def fetch_env_map(map, name) when is_binary(name) do
    case Map.fetch(map, name) do
      {:ok, value} -> {:ok, secure_if_paranoid(name, value, :map)}
      :error -> :error
    end
  end

  @doc """
  Returns the `t:Value.t/0` value of the variable from the `t:Value.env_map/0` or raises
  if not found. Same as `get_env_map/2` but raises instead of returning an `unset?/1`
  `t:Value.t/0` when the variable is not set.

  ### Examples

  ```elixir
  iex> fetch_env_map!(%{}, "UNSET")
  ** (Enviable.EnvMapError) could not fetch environment map variable "UNSET" because it is not set

  iex> value = Enviable.Codex.fetch_env_map!(%{"PORT" => "4000"}, "PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :map, ...>
  iex> to_string(value)
  "4000"

  iex> name = %Enviable.Value{name: "PORT", value: nil}
  iex> fetch_env_map!(%{"PORT" => "4000"}, name) |> to_string()
  "4000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "EnvMap"
  @spec fetch_env_map!(Value.env_map(), String.t() | Value.t()) :: Value.t()
  def fetch_env_map!(map, %Value{name: name}), do: fetch_env_map!(map, name)

  def fetch_env_map!(map, name) when is_binary(name) do
    case Map.fetch(map, name) do
      {:ok, value} -> secure_if_paranoid(name, value, :map)
      :error -> raise Enviable.EnvMapError, env: name
    end
  end

  @doc """
  Returns the `t:Value.t/0` of the variable from the `t:Value.env_map/0` or the default
  value if provided.

  Defaults behave as they do for `get_env/2`. When both a `t:Value.t/0` name and
  `default` are provided, the `default` takes precedence.

  ### Examples

  ```elixir
  iex> env = %{"PORT" => "4000"}
  iex> value = Enviable.Codex.get_env_map(env, "PORT")
  iex> value
  #Enviable.Value<name: "PORT", source: :map, ...>
  iex> to_string(value)
  "4000"
  iex> get_env_map(env, "UNSET") |> Enviable.Codex.unset?()
  true
  iex> get_env_map(env, "UNSET", "default") |> to_string()
  "default"
  iex> get_env_map(env, "UNSET", %Enviable.Value{name: "OTHER", value: "other"}) |> to_string()
  "other"

  iex> env = %{"PORT" => "4000"}
  iex> unset = %Enviable.Value{name: "UNSET", value: "fallback"}
  iex> get_env_map(env, unset) |> to_string()
  "fallback"
  iex> get_env_map(env, unset, "explicit") |> to_string()
  "explicit"
  iex> get_env_map(env, %Enviable.Value{name: "PORT", value: "fallback"}) |> to_string()
  "4000"
  ```
  """
  @doc since: "3.0.0"
  @doc group: "EnvMap"
  @spec get_env_map(Value.env_map(), String.t() | Value.t(), nil | String.t() | Value.t()) :: Value.t()
  def get_env_map(map, name_or_value, default \\ nil)

  def get_env_map(map, name_or_value, %Value{} = default) do
    value = %{get_env_map(map, name_or_value, nil) | source: :map}

    if set?(value) do
      value
    else
      %{value | value: default.value}
    end
  end

  def get_env_map(map, %Value{} = value, nil) do
    get_env_map(map, value.name, value)
  end

  def get_env_map(map, %Value{} = value, default) do
    get_env_map(map, value.name, default)
  end

  def get_env_map(map, name, default) when is_binary(name) do
    secure_if_paranoid(name, Map.get(map, name, default), :map)
  end

  @doc """
  Return the map containing secured values only.

  ### Examples

  ```elixir
  iex> env = secure_map(%{"PORT" => "4000", "EMPTY" => nil})
  iex> is_function(env["PORT"], 0)
  true
  iex> env["PORT"].()
  "4000"
  iex> env["EMPTY"]
  nil
  iex> unset = %Enviable.Value{name: "UNSET", value: "fallback"}
  iex> get_env_map(env, unset) |> to_string()
  "fallback"
  iex> get_env_map(env, unset, "explicit") |> to_string()
  "explicit"
  iex> get_env_map(env, %Enviable.Value{name: "PORT", value: "fallback"}) |> to_string()
  "4000"
  ```
  """
  @spec secure_map(Value.env_map()) :: Value.env_map()
  def secure_map(enum) do
    Map.new(enum, fn
      {k, nil} -> {k, nil}
      {k, v} -> {k, fn -> v end}
    end)
  end

  # The following functions are from system.ex in the Elixir source code.
  defp os_unsetenv(key) do
    :os.unsetenv(to_charlist(key))
  end

  defp os_putenv(key, val) do
    key = to_charlist(key)

    case :string.find(key, "=") do
      :nomatch ->
        :os.putenv(key, to_charlist(val))

      _ ->
        raise ArgumentError,
              "cannot execute put_env/1 for key with \"=\", got: #{inspect(key)}"
    end
  end

  if @paranoid do
    defp secure_if_paranoid(name, %Value{} = value, source) do
      secure(%{value | name: name, source: source})
    end

    defp secure_if_paranoid(name, value, source) do
      secure(%Value{name: name, value: value, source: source})
    end
  else
    defp secure_if_paranoid(name, %Value{} = value, source) do
      %{value | name: name, source: source}
    end

    defp secure_if_paranoid(name, value, source) do
      %Value{name: name, value: value, source: source}
    end
  end
end
