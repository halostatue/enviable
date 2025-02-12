# Enviable

- code :: https://github.com/halostatue/enviable
- issues :: https://github.com/halostatue/enviable/issues

Enviable is a small collection of functions to make working with environment
variables easier when configuring Elixir projects. It is designed to work
configuration environment loaders like [Dotenvy][Dotenvy] and provides robust
value conversion like [jetenv][jetenv].

Enviable 1.4 adds explicit functions for retrieval and conversion of encoded
values and adds a new encoded value, `list`, for delimited lists.

## Usage

Enviable will typically be imported in `config/runtime.exs` after `Config`, but
may be used anywhere that environment variables are read.

```elixir
# config/runtime.exs
import Config
import Enviable

client = fetch_env!("CLIENT")
Dotenvy.source([".env", ".env.#{client}", get_env()])

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
    {:enviable, "~> 1.3"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

`Enviable` follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/enviable
[semver]: http://semver.org/
[dotenvy]: https://hexdocs.pm/dotenvy/readme.html
[jetenv]: https://hexdocs.pm/jetenv/readme.html
