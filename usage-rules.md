# Enviable Usage Rules

Enviable is a small collection of functions to improve Elixir project
configuration via environment variables following the 12-factor application
model. It provides robust value conversion and works well with environment
loaders like Dotenvy, Nvir, or Envious.

## Core Principles

1. **Import in `config/runtime.exs`** - Standard location for runtime
   configuration
2. **Use specific conversion functions** - Prefer `fetch_env_as_integer!/1` over
   manual conversion
3. **Choose the right variant** - `fetch_*!` raises, `fetch_*` returns
   `{:ok, value} | :error`, `get_*` returns value or default
4. **Leverage type-specific functions** - Use `get_env_as_boolean/2`,
   `fetch_env_as_integer!/1`, etc.

## Decision Guide: When to Use What

### Choose Your Fetch Variant

**Use `fetch_env!/1` when:**

- Variable is required for application to run
- You want the application to crash immediately if missing
- No sensible default exists

**Use `fetch_env/1` when:**

- Variable is required but you want to handle absence explicitly
- You need pattern matching on `{:ok, value}` or `:error`
- Building conditional configuration logic

**Use `get_env/2` when:**

- Variable is optional
- You have a sensible default value
- Application can run when the result is `nil`

### Choose Your Conversion Function

**Use `fetch_env_as_TYPE!/1` when:**

- Variable is required AND needs type conversion
- You want immediate crash on missing or invalid value
- Examples: `fetch_env_as_integer!("PORT")`,
  `fetch_env_as_boolean!("ENABLE_SSL")`

**Use `fetch_env_as_TYPE/1` when:**

- Variable is required but you want explicit error handling
- Returns `{:ok, converted_value}` or `:error`
- Example: `fetch_env_as_integer("PORT")`

**Use `get_env_as_TYPE/2` when:**

- Variable is optional with a default
- Returns converted value or default
- Example: `get_env_as_integer("PORT", default: 4000)`

## Common Patterns

### Basic Configuration

```elixir
# config/runtime.exs
import Config
import Enviable

config :my_app,
  # Required values - crash if missing
  secret_key: fetch_env!("SECRET_KEY"),
  database_url: fetch_env!("DATABASE_URL"),
  
  # Required with conversion
  port: fetch_env_as_integer!("PORT"),
  
  # Optional with defaults
  ssl_enabled: get_env_as_boolean("SSL_ENABLED"),
  pool_size: get_env_as_integer("POOL_SIZE", default: 10),
  log_level: get_env_as_log_level("LOG_LEVEL", default: :info)
```

### With Environment Loaders

#### Using Nvir

```elixir
import Nvir
import Enviable

client = fetch_env!("CLIENT")
dotenv!([".env", ".env.#{client}"])

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT")
```

#### Using Dotenvy

```elixir
import Config
import Enviable

client = fetch_env!("CLIENT")
Dotenvy.source([".env", ".env.#{client}"], side_effect: &put_env/1)

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT")
```

**Important:** Dotenvy requires `side_effect: &put_env/1` because Enviable works
with the system environment table. If there is another side effect specified,
ensure that it eventually uses `System.put_env/1`.

#### Using Envious

```elixir
import Config
import Enviable

client = fetch_env!("CLIENT")
env_files = [".env", ".env.#{client}"]

loaded_env =
  Enum.reduce(env_files, %{}, fn file, acc ->
    with {:ok, contents} <- File.read(file),
         {:ok, env} <- Envious.parse(contents) do
      Map.merge(acc, env)
    else
      _ -> acc
    end
  end)

for {key, value} <- loaded_env, do: put_env_new(key, value)

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT")
```

### Type Conversions

#### Boolean Conversion

```elixir
# Only "1" and "true" return true by default (case-insensitive)
# All other values return false
# Default is false if unset
ssl_enabled: get_env_as_boolean("SSL_ENABLED")

# With explicit default
ssl_enabled: get_env_as_boolean("SSL_ENABLED", default: true)

# With custom truthy values (other values return false)
debug: get_env_as_boolean("DEBUG", truthy: ["enabled", "on"])

# With custom falsy values (other values return true)
debug: get_env_as_boolean("DEBUG", default: true, falsy: ["disabled", "off"])

# Note: Cannot specify both truthy and falsy
```

#### Integer Conversion

```elixir
# Base 10 (default)
port: fetch_env_as_integer!("PORT")

# Different bases
hex_value: get_env_as_integer("HEX_VALUE", default: 0, base: 16)
```

#### Atom Conversion

```elixir
# Unsafe - creates new atoms
env: get_env_as_atom("MIX_ENV", default: :dev)

# Safe - only existing atoms
env: get_env_as_safe_atom("MIX_ENV", default: :dev, allowed: [:dev, :test, :prod])
```

#### Module Conversion

```elixir
# Unsafe - creates new atoms
adapter: get_env_as_module("ADAPTER", default: MyApp.DefaultAdapter)

# Safe - only allowed modules
adapter: get_env_as_safe_module("ADAPTER", default: MyApp.DefaultAdapter,
  allowed: [MyApp.Adapter.Postgres, MyApp.Adapter.MySQL])
```

#### List Conversion

```elixir
# Comma-separated by default
hosts: get_env_as_list("HOSTS", default: ["localhost"])

# Custom delimiter
paths: get_env_as_list("PATHS", default: [], delimiter: ":")

# With type conversion
ports: get_env_as_list("PORTS", default: [], as: :integer)

# With complex type conversion
modules: fetch_env_as_list!("MODULES", as: :safe_module, allowed: [MyApp.A, MyApp.B])
```

### Chained Conversions

Base encoding and list conversions support an `:as` option to chain conversions:

```elixir
# Decode base64, then parse as JSON
config: fetch_env_as_base64!("CONFIG", as: :json)

# Decode base32, then convert to atom (unsafe)
name: fetch_env_as_base32!("NAME", as: :atom, downcase: true)

# Split list, then convert each element to integer
ports: fetch_env_as_list!("PORTS", as: :integer)

# Split list, then convert each to safe module
adapters: fetch_env_as_list!("ADAPTERS", as: :safe_module, 
  allowed: [MyApp.Adapter.A, MyApp.Adapter.B])

# Decode URL-safe base64, then parse as Elixir term
data: fetch_env_as_url_base64!("DATA", as: :elixir)
```

Available base encoding conversions with `:as`:

- `*_as_base16` - Base16/hex encoding
- `*_as_base32` - Base32 encoding
- `*_as_hex32` - Base32 hex encoding
- `*_as_base64` - Base64 encoding
- `*_as_url_base64` - URL-safe Base64 encoding

When using `:as`, you can also pass options for the target type:

```elixir
# Decode base64, parse as JSON with custom engine
config: fetch_env_as_base64!("CONFIG", as: :json, engine: Jason)

# Split list, convert to atoms with downcase
tags: fetch_env_as_list!("TAGS", as: :atom, downcase: true)
```

#### JSON Conversion

```elixir
# Uses configured JSON engine (Jason, JSON, :json, etc.)
config: get_env_as_json("APP_CONFIG", default: %{})

# Custom engine
config: get_env_as_json("APP_CONFIG", default: %{}, engine: Jason)
```

#### Timeout Conversion

```elixir
# Accepts timeout strings like "30s", "5m", "1h"
# Returns milliseconds as integer or :infinity
# Default is :infinity if unset
timeout: get_env_as_timeout("TIMEOUT")

# With explicit default (can be integer ms, :infinity, Duration, or keyword)
timeout: get_env_as_timeout("TIMEOUT", default: 5000)
timeout: get_env_as_timeout("TIMEOUT", default: "30s")
timeout: get_env_as_timeout("TIMEOUT", default: "PT30S")
timeout: get_env_as_timeout("TIMEOUT", default: Duration.new!(second: 30))
timeout: get_env_as_timeout("TIMEOUT", second: 30)
```

#### Duration Conversion

```elixir
# Accepts ISO8601 duration strings like "PT30S", "PT1H30M"
# Returns Duration struct
# Default is nil if unset
duration: get_env_as_duration("DURATION")

# With explicit default (can be Duration struct or ISO8601 string)
duration: get_env_as_duration("DURATION", default: "PT30S")
duration: get_env_as_duration("DURATION", default: Duration.new!(second: 30))
```

#### Base Encoding Conversions

```elixir
# Base16 (hex)
secret: fetch_env_as_base16!("SECRET_HEX")

# Base32 (standard alphabet: A-Z, 2-7)
token: fetch_env_as_base32!("TOKEN_B32")

# Base32 hex (extended hex alphabet: 0-9, A-V)
token: fetch_env_as_hex32!("TOKEN_HEX32", case: :lower)

# Base64
cert: fetch_env_as_base64!("CERTIFICATE")

# URL-safe Base64
key: fetch_env_as_url_base64!("API_KEY")
```

#### PEM Conversion

```elixir
# Parse PEM-encoded certificates/keys
cert: fetch_env_as_pem!("SSL_CERT")

# Filter specific entry types
cert: fetch_env_as_pem!("SSL_CERT", filter: :cert)
key: fetch_env_as_pem!("SSL_KEY", filter: :key)
```

### Conditional Configuration

```elixir
case fetch_env("FEATURE_FLAG") do
  {:ok, "enabled"} ->
    config :my_app, feature_enabled: true
  
  _ ->
    config :my_app, feature_enabled: false
end
```

### Setting Variables

```elixir
# Set unconditionally
put_env("MY_VAR", "value")

# Set only if not already set
put_env_new("MY_VAR", "default_value")

# Set multiple at once
put_env(%{"VAR1" => "value1", "VAR2" => "value2"})
```

## Available Conversion Types

| Type           | Function           | Description                                     |
| -------------- | ------------------ | ----------------------------------------------- |
| `:atom`        | `*_as_atom`        | Convert to atom (unsafe - creates new atoms)    |
| `:safe_atom`   | `*_as_safe_atom`   | Convert to existing atom only                   |
| `:boolean`     | `*_as_boolean`     | Convert to boolean                              |
| `:charlist`    | `*_as_charlist`    | Convert to charlist                             |
| `:decimal`     | `*_as_decimal`     | Convert to Decimal (requires `decimal` package) |
| `:duration`    | `*_as_duration`    | Convert to Duration                             |
| `:elixir`      | `*_as_elixir`      | Parse as Elixir term (unsafe)                   |
| `:erlang`      | `*_as_erlang`      | Parse as Erlang term (unsafe)                   |
| `:float`       | `*_as_float`       | Convert to float                                |
| `:integer`     | `*_as_integer`     | Convert to integer                              |
| `:json`        | `*_as_json`        | Parse as JSON                                   |
| `:list`        | `*_as_list`        | Split into list                                 |
| `:log_level`   | `*_as_log_level`   | Convert to Logger level atom                    |
| `:module`      | `*_as_module`      | Convert to module (unsafe - creates new atoms)  |
| `:safe_module` | `*_as_safe_module` | Convert to allowed module only                  |
| `:pem`         | `*_as_pem`         | Parse PEM-encoded data                          |
| `:timeout`     | `*_as_timeout`     | Convert to timeout                              |
| `:base16`      | `*_as_base16`      | Decode Base16/hex                               |
| `:base32`      | `*_as_base32`      | Decode Base32                                   |
| `:base64`      | `*_as_base64`      | Decode Base64                                   |
| `:url_base64`  | `*_as_url_base64`  | Decode URL-safe Base64                          |

## Configuration Options

### Boolean Downcase

Configure case-folding for boolean conversions:

```elixir
# config/config.exs
config :enviable, :boolean_downcase, :default  # or :ascii, :greek, :turkic
```

### JSON Engine

Configure the JSON parsing engine:

```elixir
# config/config.exs
config :enviable, :json_engine, Jason
# or
config :enviable, :json_engine, {Jason, :decode, [[floats: :decimals]]}
```

Default engines (in order of preference):

1. `JSON` (Elixir's built-in, if available)
2. `:json` (Erlang/OTP 27+)
3. `Jason` (fallback)

## Common Gotchas

1. **Atom Creation** - `*_as_atom` creates new atoms which are never garbage
   collected. Use `*_as_safe_atom` with `:allowed` option for user input.

2. **Module Creation** - `*_as_module` has the same atom creation issue. Use
   `*_as_safe_module` with `:allowed` option.

3. **Dotenvy Side Effects** - Must use `side_effect: &put_env/1` with Dotenvy
   for Enviable to see loaded variables.

4. **Boolean Defaults** - `get_env_as_boolean/2` returns `false` by default if
   unset. Only `"1"` and `"true"` (case-insensitive) return `true` by default.

5. **Integer Bases** - Base must be between 2 and 36 for `*_as_integer` with
   `:base` option.

6. **List Delimiters** - Default delimiter is comma. Use `:delimiter` option for
   other separators.

7. **Chained Conversions** - Base encoding and list functions support `:as`
   option to chain conversions (e.g., `fetch_env_as_base64!("VAR", as: :json)`).

8. **Decimal Dependency** - `*_as_decimal` functions require the `decimal`
   package to be installed.

## Function Reference

### Delegates to System

- `delete_env/1` - Delete environment variable
- `fetch_env/1` - Fetch variable, returns `{:ok, value} | :error`
- `fetch_env!/1` - Fetch variable, raises if missing
- `get_env/0` - Get all environment variables as map
- `get_env/2` - Get variable with default
- `put_env/1` - Set multiple variables from map
- `put_env/2` - Set single variable

### Enviable-Specific

- `put_env_new/2` - Set variable only if not already set

### Generic Conversion

- `get_env_as/3` - Get and convert with default
- `fetch_env_as/3` - Fetch and convert, returns `{:ok, value} | :error`
- `fetch_env_as!/3` - Fetch and convert, raises on error

### Type-Specific Conversions

Each type has three variants:

- `get_env_as_TYPE/2` - With default
- `fetch_env_as_TYPE/1` - Returns `{:ok, value} | :error`
- `fetch_env_as_TYPE!/1` - Raises on error

See "Available Conversion Types" table above for all supported types.

## Resources

- **[Hex Package](https://hex.pm/packages/enviable)** - Package on Hex.pm
- **[HexDocs](https://hexdocs.pm/enviable)** - Complete API documentation
- **[GitHub Repository](https://github.com/halostatue/enviable)** - Source code
  and issues
- **[12-Factor App](https://12factor.net/)** - Configuration methodology

## Performance Tips

1. **Minimize conversions** - Cache converted values rather than converting
   repeatedly
2. **Use specific functions** - `fetch_env_as_integer!/1` is more efficient than
   `fetch_env!/1` + manual conversion
3. **Avoid atom creation** - Use `*_as_safe_atom` and `*_as_safe_module` with
   `:allowed` lists
4. **Batch variable setting** - Use `put_env/1` with a map for multiple
   variables
