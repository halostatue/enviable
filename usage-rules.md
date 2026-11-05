# Enviable Usage Rules

Enviable improves Elixir project configuration via environment variables
following the 12-factor application model. It provides robust value conversion
and works well with environment loaders like Dotenvy, Nvir, or Envious.

Enviable offers two interfaces:

- **`Enviable.Codex`** (3.0+, **recommended for new setups**) separates value
  _retrieval_ from _conversion_. Retrieval returns an `Enviable.Value` struct;
  conversion is a separate pipe-first step. Codex also reads from environment
  maps and can read-and-erase secrets.

  ```elixir
  import Enviable.Codex
  fetch_env!("PORT") |> as_integer()
  ```

- **`Enviable`** (classic) combines retrieval and conversion in one call. It is
  fully supported and simpler for the common case of reading the system
  environment.

  ```elixir
  import Enviable
  fetch_env_as_integer!("PORT")
  ```

Pick one interface per module. Both export the same reader names
(`fetch_env`, `get_env`, …) with different return types, so importing both
collides by design.

## Which interface?

Use **`Enviable.Codex`** when any of these are true:

- you read from an environment map returned by Dotenvy or Envious, or from
  `System.get_env/0`, without pushing it into the system env table;
- you read a secret that should be erased after one read (`fetch_env_once!/1`);
- you want retrieved values wrapped in closures to resist accidental leaks
  (`:paranoid`);
- you are writing a new project and have no reason to prefer the classic
  interface.

Use **`Enviable`** when:

- you are extending an existing project already built on it;
- you read only from the system environment and want the shortest call.

Both interfaces share the same conversion catalog (types, options, chained
`:as`).

## Sub-rules

This document is the entry point. Depth lives in topic files:

- **`enviable:codex`** — the `Enviable.Codex` interface: `Enviable.Value`,
  the map (`*_env_map`) and once-only (`*_env_once`) reader families, `as_*`
  conversion, secure values, and the `:paranoid` configuration.
- **`enviable:classic`** — the classic `Enviable` interface: the
  `fetch_env_as_*` / `get_env_as_*` families and their variants.
- **`enviable:conversions`** — the conversion catalog shared by both
  interfaces: every conversion type, its options, and chained `:as`.
- **`enviable:credo`** — the optional Credo checks for unsafe atom creation and
  code evaluation.

Reference them in `mix.exs`:

```elixir
usage_rules: ["enviable:all"]            # everything
usage_rules: [:enviable, "enviable:codex", "enviable:conversions"]
```

## Core Principles

1. **Import in `config/runtime.exs`** — the standard location for runtime
   configuration, though Enviable may be used anywhere environment variables
   are read.
2. **Prefer specific conversions** — `fetch_env_as_integer!("PORT")` (classic)
   or `fetch_env!("PORT") |> as_integer()` (Codex) over manual parsing.
3. **Choose the right presence variant** — `*!` raises on an unset variable,
   non-bang `fetch_*` returns `{:ok, value} | :error`, `get_*` returns a value
   or default.
4. **Guard atom and module conversions** — use `safe_*` with `:allowed` for
   any value derived from untrusted input (see `enviable:credo`).

## Loaders

Codex is shown first (recommended); the classic equivalent follows each.

### Nvir

Nvir's `dotenv*` functions push all values back into the process environment
table, so system-environment readers work directly.

```elixir
# Codex
import Nvir
import Enviable.Codex

client = fetch_env!("CLIENT")
dotenv!([".env", ".env.#{client}"])

config :my_app,
  key: fetch_env_once!("SECRET_KEY") |> as_string(),
  port: fetch_env!("PORT") |> as_integer(),
  ssl: get_env("SSL_ENABLED") |> as_boolean()
```

```elixir
# Classic
import Nvir
import Enviable

client = fetch_env!("CLIENT")
dotenv!([".env", ".env.#{client}"])

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT"),
  ssl: get_env_as_boolean("SSL_ENABLED")
```

### Dotenvy

With Codex, read from the returned map directly; a `side_effect` that writes to
the system environment is **discouraged**.

```elixir
# Codex
import Config
import Enviable.Codex

client = fetch_env!("CLIENT")
values = Dotenvy.source!([".env", ".env.#{client}", get_env()])

config :my_app,
  key: fetch_env_map!(values, "SECRET_KEY") |> as_string(),
  port: fetch_env_map!(values, "PORT") |> as_integer(),
  ssl: get_env_map(values, "SSL_ENABLED") |> as_boolean()
```

With the classic interface, `side_effect: &put_env/1` is **required** so that
Enviable can see the loaded values in the system environment.

```elixir
# Classic
import Config
import Enviable

client = fetch_env!("CLIENT")
Dotenvy.source([".env", ".env.#{client}", get_env()], side_effect: &put_env/1)

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT"),
  ssl: get_env_as_boolean("SSL_ENABLED")
```

### Envious

Envious parses one file at a time and does not write to the environment table.
With Codex, merge the parsed maps and read from the result.

```elixir
# Codex
import Config
import Enviable.Codex

client = fetch_env!("CLIENT")
env_files = [".env", ".env.#{client}"]

loaded_env =
  Enum.reduce(env_files, %{}, fn file, acc ->
    case File.read(file) do
      {:ok, contents} -> Map.merge(acc, Envious.parse!(contents))
      _ -> acc
    end
  end)

values = Map.merge(loaded_env, get_env())

config :my_app,
  key: fetch_env_map!(values, "SECRET_KEY") |> as_string(),
  port: fetch_env_map!(values, "PORT") |> as_integer(),
  ssl: get_env_map(values, "SSL_ENABLED") |> as_boolean()
```

With the classic interface, push the merged values into the environment with
`put_env_new/2` first.

```elixir
# Classic
import Config
import Enviable

client = fetch_env!("CLIENT")
env_files = [".env", ".env.#{client}"]

loaded_env =
  Enum.reduce(env_files, %{}, fn file, acc ->
    case File.read(file) do
      {:ok, contents} -> Map.merge(acc, Envious.parse!(contents))
      _ -> acc
    end
  end)

for {key, value} <- loaded_env, do: put_env_new(key, value)

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT"),
  ssl: get_env_as_boolean("SSL_ENABLED")
```

> `Map.merge(loaded_env, get_env())` lets the real system environment override
> file values, matching 12-factor precedence. The non-bang `Dotenvy.source/2`
> returns `{:ok, map}`; the examples use `Dotenvy.source!/2` to keep the
> pipeline flat.

## Configuration

Enviable has three compile-time options, set in `config/config.exs`:

```elixir
config :enviable, :boolean_downcase, :default  # :default | :ascii | :greek | :turkic
config :enviable, :json_engine, Jason          # module or {mod, fun, args}
config :enviable, :paranoid, true               # wrap all Codex values in closures
```

- `:boolean_downcase` — case-folding for boolean conversions.
- `:json_engine` — the JSON parser. Defaults, in order: `JSON` (Elixir
  built-in), `:json` (Erlang/OTP 27+), then `Jason`.
- `:paranoid` — see `enviable:codex`. Values from the `once` family are always
  secured regardless of this setting.

## Common Gotchas

1. **One interface per module.** `Enviable` and `Enviable.Codex` share reader
   names; do not import both into the same module.
2. **Atom and module creation.** `*_as_atom` / `*_as_module` (and `as_atom` /
   `as_module`) create new atoms, which are never garbage collected. Use the
   `safe_*` form with `:allowed` for untrusted input. See `enviable:credo`.
3. **Strict options.** Invalid or misplaced options raise `Enviable.OptionError`
   (not `ArgumentError`); unsupported conversions raise
   `Enviable.UnsupportedConversionError`. Error messages never include the
   offending value.
4. **`put_env/2` with `nil`.** Deletes the variable rather than raising (unlike
   `System.put_env/2`).
5. **Dotenvy side effects (classic only).** The classic interface needs
   `side_effect: &put_env/1`; Codex reads the returned map directly.
6. **Boolean defaults.** `get_env_as_boolean/2` / `as_boolean/2` return `false`
   when unset; only `"1"` and `"true"` (case-insensitive) are true by default.
7. **Decimal dependency.** `*_as_decimal` / `as_decimal` require the `decimal`
   package.

## Resources

- **[Hex Package](https://hex.pm/packages/enviable)**
- **[HexDocs](https://enviable.hexdocs.pm/enviable)**
- **[GitHub Repository](https://github.com/halostatue/enviable)**
- **[12-Factor App](https://12factor.net/)**
