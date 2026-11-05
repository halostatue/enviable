# Enviable Credo checks

Enviable ships two optional Credo checks. Enable them in `.credo.exs` and add
`credo` as a dependency. They apply to both interfaces (`enviable:classic` and
`enviable:codex`).

```elixir
# .credo.exs
{Enviable.Credo.UnsafeAtom, []},
{Enviable.Credo.UnsafeEval, []}
```

## UnsafeAtom

Flags conversions that create atoms from environment input, which can exhaust
the atom table because atoms are not garbage collected.

Reports `*_as_atom` / `as_atom`, `*_as_module` / `as_module`, the generic
functions with an `:atom` or `:module` type (including encoded tuples like
`{:base64, :atom}`), and encoded/list conversions with `as: :atom` or
`as: :module`.

Resolve by using the safe variant or supplying `:allowed`:

```elixir
# flagged
get_env_as_atom("MIX_ENV")
fetch_env!("MOD") |> as_module()

# accepted
get_env_as_safe_atom("MIX_ENV", allowed: [:dev, :test, :prod])
fetch_env!("MOD") |> as_safe_module(allowed: [MyApp.A, MyApp.B])
get_env_as_atom("MIX_ENV", allowed: [:dev, :test, :prod])
```

The check suggests the matching safe function for the call it finds (e.g.
`fetch_env_as_safe_module!` for `fetch_env_as_module!`). Set
`permit_with_allowed: false` to flag even when `:allowed` is present.

## UnsafeEval

Flags conversions that evaluate code from environment input: `*_as_elixir` /
`as_elixir`, `*_as_erlang` / `as_erlang`, the generic functions with those
types, and encoded conversions such as `as: :elixir`.

```elixir
# flagged
get_env_as_elixir("TERM")
fetch_env!("TERM") |> as_erlang()
fetch_env!("DATA") |> as_base64(as: :elixir)
```

There is no safe variant — only use these on fully trusted input.

## What the checks see

Both checks resolve calls through `import` (honouring `only:` / `except:`),
`alias` (including `alias Enviable.Codex, as: C` and `alias Enviable.{Codex}`),
and the `Elixir.` prefix, and they follow lexical scope: a function head like
`def as_atom(value)` is not treated as a call, and an `import`/`alias` does not
leak outside its module, function, or clause. Piped calls
(`get_env("X") |> as_atom()`) and captures (`&as_atom/1`) are covered. An alias
of some other module named `Enviable` or `Codex` is not mistaken for Enviable.
