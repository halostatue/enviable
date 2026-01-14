# Enviable

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/halostatue/enviable>
- issues :: <https://github.com/halostatue/enviable/issues>

Enviable is a small collection of functions to improve Elixir project
configuration via environment variables as proposed under the [12-factor][12f]
application model. It works well with configuration environment loaders like
[Dotenvy][dotenvy], [Nvir][nvir], or [Envious][envious] and provides robust
value conversion like [jetenv][jetenv].

Enviable 2.0 removes deprecated functions and changes defaults as previously
documented. Elixir 1.17 or later is required.

## Usage

Enviable will typically be imported in `config/runtime.exs` after `Config`, but
may be used anywhere that environment variables are read.

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

### Enviable with [Dotenvy][dotenvy]

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

> #### Info {: .info}
>
> When using Dotenvy, the use of a `side_effect` that calls `System.put_env/1`
> is **required**, as Enviable works with the system environment variable table.
> Future versions of Enviable may offer ways to work with the default Dotenvy
> behaviour.

### Enviable with [Envious][envious]

```elixir
# config/runtime.exs
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
  port: fetch_env_as_integer!("PORT"),
  ssl: get_env_as_boolean("SSL_ENABLED")
```

## Installation

Enviable can be installed by adding `enviable` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:enviable, "~> 2.1"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

`Enviable` follows [Semantic Versioning 2.0][semver].

[12f]: https://12factor.net/
[docs]: https://hexdocs.pm/enviable
[dotenvy]: https://hexdocs.pm/dotenvy/readme.html
[envious]: https://github.com/jax-ex/envious
[hexpm]: https://hex.pm/package/enviable
[jetenv]: https://hexdocs.pm/jetenv/readme.html
[licence]: https://github.com/halostatue/prosody/blob/main/LICENCE.md
[nvir]: https://hexdocs.pm/nvir/readme.html
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/halostatue/enviable?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/enviable?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/enviable?style=for-the-badge&label=licence "Apache 2.0"
