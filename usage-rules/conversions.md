# Enviable conversions

The conversion catalog is shared by both interfaces. In the classic interface
(`enviable:classic`) a type `TYPE` is used through `fetch_env_as_TYPE` /
`get_env_as_TYPE`; in Codex (`enviable:codex`) through `as_TYPE` on a `Value`,
or `as(value, TYPE)`. Options are identical either way.

```elixir
# classic                              # Codex
get_env_as_integer("PORT", default: 0) fetch_env!("PORT") |> as_integer()
fetch_env_as_json!("CONFIG")           fetch_env!("CONFIG") |> as_json()
```

## Available types

| Type           | Description                                     |
| -------------- | ----------------------------------------------- |
| `:atom`        | Convert to atom (unsafe — creates new atoms)    |
| `:safe_atom`   | Convert to an existing atom only                |
| `:boolean`     | Convert to boolean                              |
| `:charlist`    | Convert to charlist                             |
| `:decimal`     | Convert to Decimal (requires `decimal`)         |
| `:duration`    | Convert to `Duration`                           |
| `:elixir`      | Parse as an Elixir term (unsafe)                |
| `:erlang`      | Parse as an Erlang term (unsafe)                |
| `:float`       | Convert to float                                |
| `:integer`     | Convert to integer                              |
| `:json`        | Parse as JSON                                   |
| `:list`        | Split into a list                               |
| `:log_level`   | Convert to a `Logger` level atom                |
| `:module`      | Convert to module (unsafe — creates new atoms)  |
| `:safe_module` | Convert to an allowed module only               |
| `:pem`         | Parse PEM-encoded data                          |
| `:string`      | Pass-through (identity)                         |
| `:timeout`     | Convert to timeout                              |
| `:base16`      | Decode Base16/hex                               |
| `:base32`      | Decode Base32                                   |
| `:hex32`       | Decode Base32 hex alphabet                      |
| `:base64`      | Decode Base64                                   |
| `:url_base64`  | Decode URL-safe Base64                          |

## Per-type options

### Boolean

```elixir
# Only "1" and "true" (case-insensitive) are true by default; unset is false.
as_boolean(v)
as_boolean(v, default: true)
as_boolean(v, truthy: ["enabled", "on"])     # listed values true, others false
as_boolean(v, default: true, falsy: ["off"]) # listed values false, others true
# :truthy and :falsy cannot both be provided.

# Map the computed boolean to arbitrary terms. :then and :else are both
# required; the result is a term, not a strict boolean(). The boolean is
# resolved first (honoring :truthy/:falsy/:default), then mapped.
as_boolean(v, then: [:inet6], else: [])
as_boolean(v, default: true, then: [:inet6], else: [])
```

### Integer / float

```elixir
as_integer(v)                      # base 10
as_integer(v, base: 16)            # base must be 2..36
as_float(v)
```

### Atom / module

```elixir
as_atom(v, default: :dev)                               # unsafe
as_safe_atom(v, default: :dev, allowed: [:dev, :test])  # existing atoms only
as_module(v, default: MyApp.Default)                    # unsafe
as_safe_module(v, allowed: [MyApp.A, MyApp.B])          # allowed modules only
```

See `enviable:credo` — prefer `safe_*` with `:allowed` for untrusted input.

### List

```elixir
as_list(v)                               # comma-separated
as_list(v, delimiter: ":")
as_list(v, as: :integer)                 # convert each element
as_list(v, as: :safe_module, allowed: [MyApp.A, MyApp.B])
```

### JSON

```elixir
as_json(v, default: %{})
as_json(v, engine: Jason)                # override configured engine
```

### Timeout

```elixir
# Accepts "30s", "5m", "PT30S"; returns ms or :infinity; unset is :infinity.
as_timeout(v)
as_timeout(v, default: 5000)
as_timeout(v, default: "30s")
as_timeout(v, default: Duration.new!(second: 30))
```

### Duration

```elixir
# Accepts ISO-8601 like "PT30S"; returns a Duration; unset is nil.
as_duration(v)
as_duration(v, default: "PT30S")
as_duration(v, default: Duration.new!(second: 30))
```

### Base encodings and PEM

```elixir
as_base16(v)
as_base32(v)
as_hex32(v, case: :lower)
as_base64(v)
as_url_base64(v)
as_pem(v, filter: :cert)   # :cert | :key to select entry types
```

## Raising on an unset variable (`:or_raise`)

Every conversion accepts `or_raise: "message"`. When the variable is unset, an
exception is raised with that message instead of returning `nil` or a
`:default`. It is mutually exclusive with `:default` — providing both raises
`Enviable.OptionError`.

```elixir
get_env("SECRET_KEY_BASE") |> as_string(or_raise: "SECRET_KEY_BASE must be set")
get_env_as_integer("PORT", or_raise: "PORT must be set")   # classic
get_env("PORT") |> as({:base64, :integer}, or_raise: "PORT must be set")
```

The `fetch_*!` / `fetch_env_as_*!` families also accept `or_raise:` (see
`enviable:classic` and `enviable:codex`); there it replaces the default
`System.EnvError` message.

## Chained conversions (`:as`)

Base-encoding and list conversions accept an `:as` option to convert the
decoded or split result, and options for the target type pass through.

```elixir
as_base64(v, as: :json)                  # decode base64, then parse JSON
as_base64(v, as: :json, engine: Jason)
as_url_base64(v, as: :elixir)            # decode, then parse an Elixir term
as_list(v, as: :integer)                 # split, then convert each element
as_list(v, as: :atom, downcase: true)
```

## Defaults

- Conversion `default:` is the value used when the variable is unset. For an
  encoded conversion it is the _decoded_ result and must match the target type:
  `{:base64, :timeout}` with `default: "30s"` yields a 30-second timeout.
  Types that do not support defaults (`:elixir`, `:erlang`, `:pem`) reject one.
- List defaults accept a plain string (split like a value), a list of strings
  (each converted), or a list already of the target type. Mixed lists are
  rejected: `{:list, :integer}` accepts `"1,2"`, `["1", "2"]`, or `[1, 2]`, but
  rejects `["1", 2]`.
- The `fetch_env_as*` / `fetch_*` families drop `:default` before conversion —
  a default makes no sense when absence raises or returns `:error`.

## Unsupported conversions

Nested encodings (`{:base64, :base16}`, `{:base32, :list}`, …) and list
elements that cannot be split reliably (`{:list, :json}`, `{:list, :elixir}`,
`{:list, :erlang}`, `{:list, :pem}`) raise
`Enviable.UnsupportedConversionError`. Encoded conversions to a primitive
target remain supported.

## Errors

- `Enviable.OptionError` — an invalid, unknown, or misplaced option. The
  message names the variable, the type, and the problem, and never includes the
  option value.
- `Enviable.ConversionError` — the value could not be converted. Names the
  variable (and list element or default, where applicable) but never the value.
- `Enviable.UnsupportedConversionError` — the conversion type itself is not
  supported.
