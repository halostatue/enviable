# Enviable

[![Hex.pm](https://img.shields.io/hexpm/v/enviable?style=for-the-badge "Hex Version")](https://hex.pm/package/enviable)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs")](https://hexdocs.pm/enviable)
[![Apache 2.0](https://img.shields.io/hexpm/l/enviable?style=for-the-badge&label=licence "Apache 2.0")](https://github.com/halostatue/enviable/blob/main/LICENCE.md)
![Coverage](https://img.shields.io/coverallsCoverage/github/halostatue/enviable?style=for-the-badge)

- code :: <https://github.com/halostatue/enviable>
- issues :: <https://github.com/halostatue/enviable/issues>

Enviable is a small collection of functions to improve Elixir project
configuration via environment variables as proposed under the [12-factor][12f]
application model. It works well with configuration environment loaders like
[Dotenvy][dotenvy], [Nvir][nvir], or [Envious][envious] and provides robust
value conversion like [jetenv][jetenv].

Enviable 3 adds an alternative interface, `Enviable.Codex`. It's not
interoperable with `Enviable`, and only one should be used, not both in the
same module. The main new features in Codex are:

- value retrieval separate from conversion;
- support for environment maps (returned from Dotenvy and Envious, or
  `System.get_env/0`) with `fetch_env_map/2`, `fetch_env_map!/2`, and
  `get_env_map/2,3`;
- once-only retrieval (get and erase) with `fetch_env_once/1`,
  `fetch_env_once!/1`, and `get_env_once/1,2`; and
- optional paranoid value handling, where retrieved values are stored in
  closures.

All Enviable.Codex value retrieval functions all return a struct implementing
`String.Chars`; it can be used in string interpolation just like values from
`System.get_env/1,2`. Outside of string interpolation, `as_string/1` is
recommended.

There are breaking changes described in the [CHANGELOG][changelog].

Enviable 3.1 extends functionality to simplify three patterns seen in Phoenix
runtime configuration templates.

- `get_env(varname) || raise message` can be folded into either `fetch_env!`
  with the `or_raise` option, or into any conversion function's `or_raise`
  option.

  ```elixir
  fetch_env!("PORT", or_raise: ~S("PORT" is a required variable))
  get_env("PORT") |> as_integer(or_raise: ~S("PORT" is a required variable))
  ```

  These will raise a runtime error with the message provided in `or_raise` if
  the value is unset.

- Boolean conversion can map the resolved boolean value to terms with `then`
  and `else` options.

  ```elixir
  ipv6_if_enabled = get_env("ECTO_IPV6") |> as_boolean(then: [:inet6], else: [])
  ipv6_if_enabled = get_env_as_boolean("ECTO_IPV6", then: [:inet6], else: [])
  ```

- Added `Enviable.Codex.env_set?/1` and `Enviable.Codex.env_unset?/1` because
  `Enviable.Codex.get_env/1` returns an `Enviable.Value` struct which is
  always truthy.

  ```elixir
  if get_env("PHX_SERVER") do
    # always truthy
  end

  if env_set?("PHX_SERVER") do
    # not always true
  end
  ```

Elixir 1.17 or later is required.

## Usage

Enviable or Enviable.Codex will typically be imported in `config/runtime.exs`
after `Config`, but may be used anywhere that environment variables are read.

### Enviable.Codex with [Nvir][nvir]

The Nvir `dotenv*` functions always return an environment map, but it
automatically pushes all values back into the process environment table.

```elixir
import Nvir
import Enviable.Codex

client = fetch_env!("CLIENT")
dotenv!([".env", ".env.#{client}"])

config :my_app,
  key: fetch_env_once!("SECRET_KEY") |> as_string(),
  port: fetch_env!("PORT") |> as_integer(),
  ssl: get_env("SSL_ENABLED") |> as_boolean()
```

### Enviable with [Nvir][nvir]

```elixir
import Nvir
import Enviable

client = fetch_env!("CLIENT")
dotenv!([".env", ".env.#{client}"])

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT"),
  ssl: get_env_as_boolean("SSL_ENABLED")
```

### Enviable.Codex with [Dotenvy][dotenvy]

The use of a `side_effect` calling `System.put_env/1` is _discouraged_ with
Enviable.Codex.

```elixir
import Config
import Enviable.Codex

client = fetch_env!("CLIENT")
values = Dotenvy.source!([".env", ".env.#{client}", get_env()])

config :my_app,
  key: fetch_env_map!(values, "SECRET_KEY") |> as_string(),
  port: fetch_env_map!(values, "PORT") |> as_integer(),
  ssl: get_env_map(values, "SSL_ENABLED") |> as_boolean()
```

### Enviable with [Dotenvy][dotenvy]

The use of a `side_effect` that calls `System.put_env/1` is **required** with
Enviable.

```elixir
# config/runtime.exs
import Config
import Enviable

client = fetch_env!("CLIENT")
Dotenvy.source([".env", ".env.#{client}", get_env()], side_effect: &put_env/1)

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_as_integer!("PORT"),
  ssl: get_env_as_boolean("SSL_ENABLED")
```

### Enviable.Codex with [Envious][envious]

Envious parses a single file at a time and doesn't write to the environment
variable table.

```elixir
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

### Enviable with [Envious][envious]

Envious parses a single file at a time and doesn't write to the environment
variable table. To work with Enviable, we put the values into the environment
with `put_env_new/2`.

```elixir
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

## Installation

Enviable can be installed by adding `enviable` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:enviable, "~> 3.0"},
    # Optional, required for decimal conversion
    {:decimal, "~> 2.3"},
    # Optional, required only if :json or JSON aren't available or another
    # JSON engine is not configured
    {:jason, "~> 1.4"},
    # Optional, if using the Enviable credo checks
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

`Enviable` follows [Semantic Versioning 2.0][semver].

[12f]: https://12factor.net/
[changelog]: https://enviable.hexdocs.pm/CHANGELOG.html
[docs]: https://enviable.hexdocs.pm/
[dotenvy]: https://dotenvy.hexdocs.pm/readme.html
[envious]: https://envious.hexdocs.pm/readme.html
[jetenv]: https://jetenv.hexdocs.pm/readme.html
[nvir]: https://nvir.hexdocs.pm//readme.html
[semver]: https://semver.org/
