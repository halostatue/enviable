# Enviable.Codex

`Enviable.Codex` separates value _retrieval_ from _conversion_. Retrieval
returns an `Enviable.Value`; conversion is a separate pipe-first step.

```elixir
import Enviable.Codex

fetch_env!("PORT") |> as_integer()
```

This is the recommended interface for new projects. See `enviable:conversions`
for the full conversion catalog (every type and its options); this file covers
retrieval, the `Value` struct, and secure values.

## Enviable.Value

Codex readers return `t:Enviable.Value.t/0`, not `nil` or `t:String.t/0`. The
struct carries the variable's name and provenance and implements `String.Chars`.

```elixir
port = fetch_env!("PORT")
inspect(port)     # => #Enviable.Value<name: "PORT", source: :env, ...>
to_string(port)   # => "5432"
as_integer(port)  # => 5432
```

- **`String.Chars`** — usable in interpolation; `to_string/1` on an unset value
  returns `""`. For conversion to a string outside interpolation, prefer
  `as_string/1`.
- **`Inspect`** — hides the value, so a `Value` can be logged without leaking a
  secret.
- **`set?/1` / `unset?/1`** — test whether the inner value is present.

A `Value` may be passed anywhere Codex takes a variable name or value, including
`get_env/1,2`, `put_env/1,2`, and `put_env_new/1,2`.

## Reader families

### System environment

```elixir
fetch_env!("PORT")      # Value, raises System.EnvError if unset
fetch_env("PORT")       # {:ok, Value} | :error
get_env("PORT")         # Value (unset unless defaulted)
get_env("PORT", "4000") # Value wrapping the default when unset
```

### Environment maps

Reads from an `t:Enviable.Value.env_map/0` (e.g. the result of
`Dotenvy.source/1,2` or `System.get_env/0`) without touching the system env
table. The map is the first argument.

```elixir
{:ok, values} = Dotenvy.source([".env", get_env()])

fetch_env_map!(values, "PORT") |> as_integer()
fetch_env_map(values, "PORT")              # {:ok, Value} | :error
get_env_map(values, "PORT", "4000")        # Value, with default
```

`fetch_env_map!/2` raises `Enviable.EnvMapError` when the key is absent.

### Once-only (read-and-erase)

Reads from the system environment and then erases the variable, so a secret is
not carried to child processes or re-read elsewhere. Erasure happens during the
read, before any conversion runs.

```elixir
fetch_env_once!("SECRET_KEY") |> as_string()
fetch_env_once("SECRET_KEY")   # {:ok, Value} | :error
get_env_once("SECRET_KEY")     # Value
```

There is no map variant — a map is not the system env table, so there is
nothing to erase.

## Secure values

A **secure** `Value` wraps its inner value in a closure, so the value does not
appear under `inspect(value, structs: false)`, Erlang's `~p` in crash dumps, or
other formatting that bypasses the `Inspect` protocol. (The default `inspect/2`
already hides it.)

- Values from the **once** family are **always** secure.
- `Enviable.Value.secure/1` secures a single value;
  `Enviable.Codex.secure_map/1` secures every value in a map.
- `secure?/1` reports whether a value is secure.

```elixir
fetch_env!("TOKEN") |> secure() |> as_string()

values |> secure_map() |> fetch_env_map!("TOKEN") |> as_string()
```

### Paranoid mode

`config :enviable, :paranoid, true` (compile-time) makes **all** Codex
retrieval functions return secure values, not only the once family.

```elixir
# config/config.exs
config :enviable, :paranoid, true
```

Secure values still reveal their contents through `to_string/1`, string
interpolation, and `as_string/1` — those are deliberate reads. Securing guards
against _accidental_ exposure (logging a struct, a crash dump), not against code
that explicitly asks for the value. The operating system may also still expose
the original environment variable (for example via `/proc/<pid>/environ`), and
any code that read it before the once-erase keeps its own copy.

## Setting and deleting

```elixir
put_env("PORT", "4000")
put_env("PORT", nil)                 # deletes (System.put_env/2 would raise)
put_env(%Enviable.Value{name: "PORT", value: nil})  # deletes by name
put_env_new("PORT", "4000")          # set only if unset
delete_env("PORT")
```

An unset `Value` (or `nil`) passed as the value deletes the variable.
