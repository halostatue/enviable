# Enviable (classic interface)

The classic `Enviable` interface combines retrieval and conversion in one call.
It is fully supported; `Enviable.Codex` (see `enviable:codex`) is recommended
for new projects. See `enviable:conversions` for the full conversion catalog.

```elixir
import Enviable

fetch_env_as_integer!("PORT")
```

## Readers

```elixir
fetch_env!("SECRET_KEY")   # String, raises if unset
fetch_env("SECRET_KEY")    # {:ok, String} | :error
get_env("PORT")            # String | nil
get_env("PORT", "4000")    # String, with default
```

## Conversion functions

Each conversion type has three variants:

| Variant                  | Returns                     | Use when                            |
| ------------------------ | --------------------------- | ----------------------------------- |
| `fetch_env_as_TYPE!/1,2` | converted value, or raises  | required; crash if missing/invalid  |
| `fetch_env_as_TYPE/1,2`  | `{:ok, value}` \| `:error`  | required; handle absence explicitly |
| `get_env_as_TYPE/2`      | converted value, or default | optional, with a default            |

```elixir
config :my_app,
  secret_key: fetch_env!("SECRET_KEY"),
  database_url: fetch_env!("DATABASE_URL"),
  port: fetch_env_as_integer!("PORT"),
  ssl_enabled: get_env_as_boolean("SSL_ENABLED"),
  pool_size: get_env_as_integer("POOL_SIZE", default: 10),
  log_level: get_env_as_log_level("LOG_LEVEL", default: :info)
```

### Generic conversion

When the type is dynamic, use the generic functions with a conversion type (see
`enviable:conversions`):

```elixir
get_env_as("PORT", :integer, default: 4000)
fetch_env_as("PORT", :integer)        # {:ok, value} | :error
fetch_env_as!("PORT", :integer)       # raises on error
```

## Choosing a presence variant

- **`fetch_env_as_TYPE!/1`** — the variable is required and the app should crash
  immediately if it is missing or invalid.
- **`fetch_env_as_TYPE/1`** — required, but you want to pattern-match
  `{:ok, value}` / `:error` and build conditional configuration.
- **`get_env_as_TYPE/2`** — optional, with a sensible default.

### Custom messages on an unset variable

The `fetch_env!/2` and `fetch_env_as_TYPE!/2` functions accept
`or_raise: "message"`; when the variable is unset, the message replaces the
default `System.EnvError` text.

```elixir
fetch_env!("SECRET_KEY", or_raise: "SECRET_KEY must be set")
fetch_env_as_integer!("PORT", or_raise: "PORT must be set")
```

The `get_env_as_TYPE/2` conversions also accept `or_raise:` to raise on an
unset variable instead of returning a default (see `enviable:conversions`).

## Setting and deleting

```elixir
put_env("MY_VAR", "value")
put_env("MY_VAR", nil)                       # deletes (System.put_env/2 would raise)
put_env_new("MY_VAR", "default")             # set only if unset
put_env(%{"VAR1" => "value1", "VAR2" => "value2"})
delete_env("MY_VAR")
```

## Relationship to Enviable.Codex

`Enviable` is implemented over `Enviable.Codex` and no longer delegates to
`System`. Its readers still return plain strings (or `nil`), never
`Enviable.Value`. `fetch_env/1`, `fetch_env!/1`, `get_env/2`, and `delete_env/1`
also accept an `Enviable.Value` as the variable, and `put_env/1,2` /
`put_env_new/1,2` accept one as the variable or value.
