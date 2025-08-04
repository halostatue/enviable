# Contributing

Contribution to Enviable is encouraged: bug reports, discussions, feature
requests, or code contributions. New features should be proposed and discussed
in an [issue][issues].

Before contributing patches, please read the [Licence](./LICENCE.md).

Enviable is governed under the [Contributor Covenant Code of Conduct][cccoc].

## Code Guidelines

I have several guidelines to contributing code through pull requests:

- All code changes require tests. In most cases, this will be added or updated
  unit tests. I use [ExUnit][exunit].

- I use code formatters, static analysis tools, and linting to ensure consistent
  styles and formatting. There should be no warnings output from compile or test
  run processes. I use `mix compile --warnings-as-errors`, [Credo][credo], and
  `mix format` (with [Quokka][quokka]).

- Proposed changes should be on a thoughtfully-named topic branch and organized
  into logical commit chunks as appropriate.

- Use [Conventional Commits][conventional] with our
  [conventions](#commit-conventions).

- Versions must not be updated in pull requests.

- Documentation should be added or updated as appropriate for new or updated
  functionality.

- New dependencies are discouraged and their addition must be discussed,
  regardless whether it is a development dependency, optional dependency, or
  runtime dependency.

- All GitHub Actions checks marked as required must pass before a pull request
  may be accepted and merged.

## LLM-Generated Contribution Policy

Enviable contributions must be well understood by the submitter and that,
especially for pull requests, the developer can attest to the
[Developer Certificate of Origin][dco] for each pull request (see
[LICENCE](LICENCE.md)).

If LLM assistance is used in writing pull requests, this must be documented in
the commit message and pull request. If there is evidence of LLM assistance
without such declaration, the pull request **will be declined**.

Any contribution (bug, feature request, or pull request) that uses unreviewed
LLM output will be rejected.

### Commit Conventions

Enviable has adopted a variation of the Conventional Commits format for commit
messages. The following types are permitted:

| Type    | Purpose                                               |
| ------- | ----------------------------------------------------- |
| `feat`  | A new feature                                         |
| `fix`   | A bug fix                                             |
| `chore` | A code change that is neither a bug fix nor a feature |
| `docs`  | Documentation updates                                 |
| `deps`  | Dependency updates, including GitHub Actions.         |

I encourage the use of [Tim Pope's][tpope-qcm] or [Chris Beam's][cbeams]
guidelines on the writing of commit messages

I require the use of [git][trailers1] [trailers][trailers2] for specific
additional metadata and strongly encourage it for others. The conditionally
required metadata trailers are:

- `Breaking-Change`: if the change is a breaking change. **Do not** use the
  shorthand form (`feat!(scope)`) or `BREAKING CHANGE`.

- `Signed-off-by`: this is required for all developers except me, as outlined in
  the [Licence](./LICENCE.md#developer-certificate-of-origin).

- `Fixes` or `Resolves`: If a change fixes one or more open [issues][issues],
  that issue must be included in the `Fixes` or `Resolves` trailer. Multiple
  issues should be listed comma separated in the same trailer:
  `Fixes: #1, #5, #7`, but _may_ appear in separate trailers. While both `Fixes`
  and `Resolves` are synonyms, only _one_ should be used in a given commit or
  pull request.

- `Related to`: If a change does not fix an issue, those issue references should
  be included in this trailer.

## Contributors

Austin Ziegler created Enviable.

[cbeams]: https://cbea.ms/git-commit/
[cccoc]: ./CODE_OF_CONDUCT.md
[conventional]: https://www.conventionalcommits.org/en/v1.0.0/
[credo]: https://github.com/rrrene/credo
[dco]: licences/dco.txt
[exunit]: https://hexdocs.pm/ex_unit/ExUnit.html
[issues]: https://github.com/halostatue/enviable/issues
[quokka]: https://github.com/emkguts/quokka
[tpope-qcm]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[trailers1]: https://git-scm.com/docs/git-interpret-trailers
[trailers2]: https://git-scm.com/docs/git-commit#Documentation/git-commit.txt---trailerlttokengtltvaluegt
