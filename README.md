# Enviable

- code :: https://github.com/halostatue/enviable
- issues :: https://github.com/halostatue/enviable/issues

Enviable is a small collection of functions to improve Elixir project
configuration via environment variables as proposed under the [12-factor][12f]
application model. It works well with configuration environment loaders like
[Dotenvy][dotenvy] or [Nvir][nvir] and provides robust value conversion like
[jetenv][jetenv].

Enviable 2.0 removes deprecated functions and changes defaults as previously
documented. Elixir 1.17 or later is required.

## Usage

Enviable will typically be imported in `config/runtime.exs` after `Config`, but
may be used anywhere that environment variables are read.

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

## Installation

Enviable can be installed by adding `enviable` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:enviable, "~> 2.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

`Enviable` follows [Semantic Versioning 2.0][semver].

[12f]: https://12factor.net/
[docs]: https://hexdocs.pm/enviable
[dotenvy]: https://hexdocs.pm/dotenvy/readme.html
[jetenv]: https://hexdocs.pm/jetenv/readme.html
[nvir]: https://hexdocs.pm/nvir/readme.html
[semver]: https://semver.org/
