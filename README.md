# Enviable

- code :: https://github.com/halostatue/enviable
- issues :: https://github.com/halostatue/enviable/issues

## Description

Enviable is a small collection of functions and delegates that makes working
with operating system environment functions a little easier. It exists for two
reasons:

- Functions like `Enviable.put_env_new/2` do not exist in `System` and are
  easier to read than either `System.put_env/2` or `System.put_env/1` in
  conjunction with `Ssytem.get_env/2`.

- Modules in dependencies can reliably be used or `include`d in configuration
  files in ways that in-source functions cannot be.

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
