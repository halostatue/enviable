# Enviable Changelog

## 3.0.0 / 2026-11-06

> Implemented with [Kiro][kiro], mostly using Claude Opus 5.5. Most of the
> Codex implementations were hand-written and verified, but various bugs were
> found and fixed with agent assistance.

This release contains a major new feature and breaking changes.

### Enviable.Codex

The new `Enviable.Codex` interface separates value retrieval from conversion.
At first glance, this seems strictly worse than the unified functions in
Enviable, but Codex adds two families of value retrieval functions that
justify the split.

```elixir
import Enviable
fetch_env_as_integer!("PORT")

import Enviable.Codex
fetch_env!("PORT") |> as_integer()
```

The first family reads from an environment map (`t:Enviable.Value.env_map/0`),
like the results of `Dotenvy.source/1,2` or `System.get_env()`. These
functions are `fetch_env_map/2`, `fetch_env_map!/2`, and `get_env_map/2,3`.

```elixir
import Enviable.Codex
{:ok, values} = Dotenvy.source([".env", get_env()])
fetch_env_map(values, "PORT") |> as_integer()
```

The second family reads from the environment, and then erases the value after
reading it, preventing secrets from being carried to child processes or
accessed from code that should instead be reading from application config.
These functions are `fetch_env_once/1`, `fetch_env_once!/1`, and
`get_env_once/1,2`.

```elixir
import Enviable.Codex
fetch_env_once!("PORT") |> as_integer()
fetch_env_once!("PORT") # raises System.EnvError
```

Codex values are retrieved as `t:Enviable.Value.t/0`, not `nil` or
`t:String.t/0`. This struct implements the `String.Chars` protocol and
suppresses the value on inspect (protecting secrets from accidental exposure).
Values can be paranoid: the inner value retrieved can be wrapped in a closure
closing all accidental leak paths (`Enviable.Value.secure?/1`). Values
retrieved with the `once` family of Codex functions are _always_ secure, but
paranoia can be enabled for all Enviable.Codex values
(`config :enviable, :paranoid, true`).

```elixir
import Enviable.Codex
port = fetch_env!("PORT")
inspect(port)     # => #Enviable.Value<name: "PORT", source: :env, ...>
to_string(port)   # => "5432"
as_integer(port)  # => 5432
```

Use `Enviable.Value.set?/1` and `Enviable.Value.unset?/1` to determine whether
the value is set or unset. Within the Codex interface, `Value` can be passed
to all environment functions (such as `get_env/1,2` and `put_env_new/1,2`).

### Breaking changes

- Conversion options validation has been moved from a hand-written mess to
  [NimbleOptions][nimble_options] schemas. This changes where and how some
  errors are generated and makes options validation and parsing much stricter.
  These will be raised as `Enviable.OptionError`.

- Nested encodings (`{:base64, :base16}`, `{:base32, :list}`, etc.) are no
  longer permitted. Similarly, `{:list, :json}`, `{:list, :elixir}`,
  `{:list, :erlang}`, and `{:list, :pem}` are disallowed with
  `Enviable.UnsupportedConversionError`.

- `default:` value semantics for lists and encoded conversions have been
  refined; this likely changes from what was previously permitted.

  Encoded conversion defaults must match the target type. The default value
  for `{:base64, :timeout}` must match what a `:timeout` permits. If the
  target type doesn't permit defaults (like `:elixir`, `:erlang`, and `:pem`),
  the default will be rejected.

  List conversion defaults handle plain strings (just like a normal value),
  lists of strings (each element converted like a normal value), and lists of
  the target type. Mixed lists aren't permitted. A `{:list, :integer}` could
  correctly use default values of `"1,2"`, `["1", "2"]`, and `[1, 2]`. It
  would reject `["1", 2]`.

  List defaults are _checked_ when options are parsed, but _converted_ only if
  the value is unset.

- The `fetch_env_as/3`, `fetch_env_as!/3`, and the `fetch_env_as_*` functions
  drop `:default` before conversion.

- `Enviable.put_env/2` no longer raises an error if provided `nil` as the
  value, but instead deletes the environment variable.

- The `@spec` and `@type` definitions have changed, especially for conversion
  options and functions; they're now derived from the NimbleOptions schema.

### Changes

- `:string` is a conversion primitive; it's just a pass-through. Lists
  (`{:list, :string}`) returns `list(String.t())` and encoded types
  (`{:base64, :string}`, etc.) `binary()`.

- `Enviable` has been reimplemented over `Enviable.Codex`. The environment
  functions no longer delegate to `System`. `fetch_env/1`, `fetch_env!/1`,
  `get_env/2`, and `delete_env/1` accept `t:Enviable.Value.t/0` as the
  variable.

  `put_env/1,2` and `put_env_new/1,2` accept `t:Enviable.Value.t/0` as
  variable or value. If the value side is `nil` or `unset?/1`, the variable
  will be deleted. `put_env/1,2` has been modified to delete the environment
  variable when provided `nil` or an unset Value.

- The Credo checks have been extended to cover Enviable.Codex conversions.
  `Enviable.Credo.UnsafeAtom` suggestions name the matching safe function
  (`fetch_env_as_safe_module!` instead of always `get_env_as_safe_module`).

## 2.3.0 / 2026-05-12

- Extended support for Decimal 3.
- Updated dependencies.

## 2.2.1 / 2026-04-11

- Fixed an issue where the Enviable [Credo][credo] checks only work if you
  have Credo 1.7.14 or higher, but the requirement says any Credo version 1.0
  or higher. This has been resolved by restricting the minimum version of
  Credo required. For most users, this should be sufficient. Please file an
  [issue][issues] if you cannot upgrade to this version of Credo.

## 2.2.0 / 2026-01-25

- Added support for [`Duration`][duration] values. This includes updating the
  support for `timeout` conversions to parse ISO 8601 duration
  representations.

- Added [usage rules](./usage-rules.md) for use with [`usage_rules`][urules].

  The usage rules were built with the assistance of [Kiro][kiro].

## 2.1.0 / 2026-01-13

- Added `Enviable.Credo.UnsafeAtom` as an optional [Credo][credo] check. When
  enabled in `.credo.exs`, it will report on the use of Enviable functions and
  conversion options that may result in atom exhaustion. This includes the
  `*_as_atom*` and `*_as_module*` functions, the `:atom` or `:module`
  conversion type, or an encoded conversion which uses `:atom` or `:module`.
  Warnings will not be shown when the `:allow` option is provided.

- Added `Enviable.Credo.UnsafeEval` as an optional [Credo][credo] check. When
  enabled in `.credo.exs`, it will report on the use of unsafe code evaluation
  checks (the `*_as_elixir*` and `*_as_erlang*` functions).

> These checks and their tests were developed with the assistance of
> [Kiro][kiro].

## 2.0.0 / 2025-12-26

- Breaking changes:

  - Enviable 2.0 supports Elixir 1.17+ only.

  - Deprecated functions have been removed: `get_env_boolean/2`,
    `get_env_integer/2`, `fetch_env_boolean/2`, `fetch_env_integer/2`,
    `fetch_env_boolean!/2`, and `fetch_env_integer!/2`.

  - The default value for `boolean_downcase` and `downcase` for boolean
    conversion is `:default`. This also required changing some conversion
    types to distinguish between boolean case conversion and atom case
    conversion.

  - The default value for `case` on `base16`, `base32`, and `hex32` conversion
    has changed from `:upper` to `:mixed`.

## 1.7.0 / 2025-10-15

> The next major version of Enviable will support Elixir 1.17+ only.

- Added support for timeout values processed through
  [`to_timeout`][to_timeout].

  - Added a parser built with [`nimble_parsec`][nimble_parsec] to parse
    timeout strings. This parser (Enviable.Conversion.TimeoutParser) and unit
    tests were developed with the assistance of [Kiro][kiro] with
    [Timeout Values][timeout] as the initial prompt with human review and
    revision.

## 1.6.0 / 2025-08-12

- Improved examples for using [`Dotenvy`][dotenvy] and added references to
  [`Nvir`][nvir] as a compatible library.

- Added support for the new JSON module in Elixir 1.18.

- Added support for [Decimal][decimal].

## 1.5.0 / 2025-03-04

- Fixed a bug with `list` conversion for `get_env_as_list` and `get_env_as`
  where support for a `:default` value was not included.

- Fixed a bug with `:downcase` conversions and nil values.

- Added a compile-time configuration option to change the default boolean
  `:downcase` option. The default value is currently `false` (do not
  downcase).

  The next major version of Enviable will change this to `:default`, as it
  should not matter whether the matched value is `true`, `TRUE`, or `True` for
  boolean tests.

- Added `:upcase` option to `atom` and `safe_atom` conversions.

- Fixed `:json_engine` configuration so that it is properly compile-time and
  referenced. The JSON parsing code was looking this up at runtime under the
  wrong key.

- Added support for `{m, f, a}` specification for `:json_engine` configuration
  or the `:engine` parameter for JSON conversion.

## 1.4.0 / 2025-02-11

- Added `list` conversion for delimiter-separated lists. This supports all
  options of `String.split/3`.

- Added `*_env_as_TYPE/2` functions for all encoded conversions (`base16`,
  `base32`, `hex32`, `base64`, `url_base64`, and `list`).

- Internal:

  - Added an internal config module to split the configuration from the
    conversion code for improved readability.

  - Updated doc names to how I now structure my projects.

  - Add [`excoveralls`][excoveralls] for coverage.

## 1.3.0 / 2025-01-16

- Added explicit functions for retrieval and conversion of primitives to
  assist with language servers and IDEs as an alternative to `*_env_as/3`
  functions. Most of these new functions are `*_env_as_TYPE/2`, but several
  are `*_env_as_TYPE/1` as there are no applicable options.

  Encoded conversions (`:base*`) do not have named functions and must be
  accessed through `*_env_as/3`.

- Soft-deprecated `*_env_integer` and `*_env_boolean` functions in favour of
  `*_env_as_integer` and `*_env_as_boolean`. There will be at least one
  release of Enviable 1.x which marks these functions as deprecated so that
  compiler warnings are generated.

## 1.2.1 / 2025-01-02

- Fixed a function definition bug with `fetch_env_as/3` and `fetch_env_as!/3`
  preventing them from being `fetch_env_as/2` and `fetch_env_as!/2`.

## 1.2.0 / 2024-12-29

- Added conversions for `log_level`.
- Add Elixir 1.18 / OTP 27 to the test matrix.
- Update dependencies.
- Add [`mise`][mise] configuration.
- Fix dialyzer configuration.

## 1.1.0 / 2024-12-22

- Extended conversions through `get_env_as/3`, `fetch_env_as/3`, and
  `fetch_env_as!/3`.

- Fixed more documentation issues.

## 1.0.1 / 2024-12-11

- Fixed documentation issues.

## 1.0.0 / 2024-12-10

- Initial release.

[credo]: https://github.com/rrrene/credo
[decimal]: https://hexdocs.pm/decimal/readme.html
[dotenvy]: https://hexdocs.pm/dotenvy/readme.html
[duration]: https://hexdocs.pm/elixir/Duration.html
[excoveralls]: https://hexdocs.pm/excoveralls/readme.html
[kiro]: https://kiro.dev
[nimble_options]: https://hexdocs.pm/nimble_options
[mise]: https://mise.jdx.dev
[nimble_parsec]: https://hexdocs.pm/nimble_parsec/NimbleParsec.html
[nvir]: https://hexdocs.pm/nvir/readme.html
[issues]: https://github.com/halostatue/enviable/issues
[timeout]: `m:Enviable#fetch_env_as_timeout/1-timeout-values`
[to_timeout]: https://hexdocs.pm/elixir/Kernel.html#to_timeout/1
[urules]: https://github.com/ash-project/usage_rules
