# Enviable

- code :: https://github.com/halostatue/enviable
- issues :: https://github.com/halostatue/enviable/issues

Enviable is a small collection of functions and delegates that makes working
with operating system environment functions a little easier. It exists for two
reasons:

- Functions like `Enviable.put_env_new/2` do not exist in `System` and are
  easier to read than either `System.put_env/2` or `System.put_env/1` in
  conjunction with `System.get_env/2`.

- Modules in dependencies can reliably be used or `include`d in configuration
  files in ways that in-source functions cannot be.

Delegates are defined for `System.delete_env/1`, `System.fetch_env/1`,
`System.fetch_env!/1`, `System.get_env/0`, `System.get_env/2`,
`System.put_env/1`, and `System.put_env/2`.

## Usage

This will typically be used in `config/*.exs` files alongside [Dotenvy][dotenvy]
or similar configuration tools based around environment variables.

```elixir
# config/runtime.exs
include Config
include Enviable

client = fetch_env!("CLIENT")
Dotenvy.source([".env", ".env.#{client}", System.get_env()])

config :my_app,
  key: fetch_env!("SECRET_KEY"),
  port: fetch_env_integer!("PORT"),
  ssl: fetch_env_boolean!("SSL_ENABLED")
```

```elixir
# config/dev.exs
include Config
Enviable.put_env_new("SSL_ENABLED", false)
```

## Installation

Enviable can be installed by adding `enviable` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:enviable, "~> 0.1.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

`Enviable` uses a [Semantic Versioning][semver] scheme with one significant
change:

- When PATCH is zero (`0`), it will be omitted from version references.

[docs]: https://hexdocs.pm/enviable
[semver]: http://semver.org/
[dotenvy]: https://hexdocs.pm/dotenvy/readme.html
