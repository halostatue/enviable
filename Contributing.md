# Contributing

I value contributions to Enviable--bug reports, discussions, feature requests,
and code contributions. New features should be proposed and
[discussed][discussed].

Before contributing patches, please read the [Licence](./Licence.md).

Enviable is governed under the [Contributor Covenant Code of Conduct][cccoc].

## Code Guidelines

We have several guidelines to contributing code through pull requests to App
Identity reference implementations:

- All code changes require tests. In most cases, this will be added or updated
  unit tests. We use [ExUnit][ExUnit].

- We use code formatters, static analysis tools, and linting to ensure
  consistent styles and formatting. There should be no warnings output from
  compile or test run processes. We use `mix compile --warnings-as-errors`,
  [Credo][Credo], and `mix format` (with [Styler][Styler])

- Proposed changes should be on a thoughtfully-named topic branch and organized
  into logical commit chunks as appropriate.

- Use [Conventional Commits][conventional] with our [conventions][conventions].

- Versions must not be updated in pull requests.

- Documentation should be added or updated as appropriate for new or updated
  functionality.

- New dependencies are discouraged and their addition must be discussed,
  regardless whether it is a development dependency, optional dependency, or
  runtime dependency.

- All GitHub Actions checks marked as required must pass before a pull request
  may be accepted and merged.

[cccoc]: ./Code-of-Conduct.md
[conventional]: https://www.conventionalcommits.org/en/v1.0.0/
[conventions]: https://github.com/KineticCafe/app-identity/blob/main/Contributing.md#commit-conventions
[credo]: https://github.com/rrrene/credo
[styler]: https://github.com/adobe/styler
[discussed]: https://github.com/halostatue/enviable/discussions
[exunit]: https://hexdocs.pm/ex_unit/ExUnit.html
