# Enviable Changelog

## 2.1.0 / 2026-01-13

- Added `Enviable.Credo.UnsafeAtom` as an optional [Credo][credo] check. When
  enabled in `.credo.exs`, it will report on the use of Enviable functions and
  conversion options that may result in atom exhaustion. This includes the
  `*_as_atom*` and `*_as_module*` functions, the `:atom` or `:module` conversion
  type, or an encoded conversion which uses `:atom` or `:module`. Warnings will
  not be shown when the `:allow` option is provided.

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
    conversion is `:default`. This also required changing some conversion types
    to distinguish between boolean case conversion and atom case conversion.

  - The default value for `case` on `base16`, `base32`, and `hex32` conversion
    has changed from `:upper` to `:mixed`.

## 1.7.0 / 2025-10-15

> The next major version of Enviable will support Elixir 1.17+ only.

- Added support for timeout values processed through [`to_timeout`][to_timeout].

  - Added a parser built with [`nimble_parsec`][nimble_parsec] to parse timeout
    strings. This parser (Enviable.Conversion.TimeoutParser) and unit tests were
    developed with the assistance of [Kiro][kiro] with [Timeout Values][timeout]
    as the initial prompt with human review and revision.

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
  `:downcase` option. The default value is currently `false` (do not downcase).

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

- Added explicit functions for retrieval and conversion of primitives to assist
  with language servers and IDEs as an alternative to `*_env_as/3` functions.
  Most of these new functions are `*_env_as_TYPE/2`, but several are
  `*_env_as_TYPE/1` as there are no applicable options.

  Encoded conversions (`:base*`) do not have named functions and must be
  accessed through `*_env_as/3`.

- Soft-deprecated `*_env_integer` and `*_env_boolean` functions in favour of
  `*_env_as_integer` and `*_env_as_boolean`. There will be at least one release
  of Enviable 1.x which marks these functions as deprecated so that compiler
  warnings are generated.

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
[excoveralls]: https://hexdocs.pm/excoveralls/readme.html
[kiro]: https://kiro.dev
[mise]: https://mise.jdx.dev
[nimble_parsec]: https://hexdocs.pm/nimble_parsec/NimbleParsec.html
[nvir]: https://hexdocs.pm/nvir/readme.html
[timeout]: `m:Enviable#fetch_env_as_timeout/1-timeout-values`
[to_timeout]: https://hexdocs.pm/elixir/Kernel.html#to_timeout/1
