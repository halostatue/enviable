# Enviable Changelog

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
- Add mise configuration.
- Fix dialyzer configuration.

## 1.1.0 / 2024-12-22

- Extended conversions through `get_env_as/3`, `fetch_env_as/3`, and
  `fetch_env_as!/3`.

- Fixed more documentation issues.

## 1.0.1 / 2024-12-11

- Fixed documentation issues.

## 1.0.0 / 2024-12-10

- Initial release.
