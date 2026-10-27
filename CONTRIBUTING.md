# Contributing to PulseBeam

PulseBeam is being developed incrementally with an engineering-first workflow.

## Development flow

1. Start from an Issue with clear acceptance criteria.
2. Create a focused branch from `main`.
3. Implement the smallest coherent change.
4. Add or update tests when behavior changes.
5. Update documentation when requirements, architecture, or user-visible behavior changes.
6. Open a Pull Request referencing the Issue and related requirement/user story.

## Suggested branch names

```text
feature/<short-description>
fix/<short-description>
docs/<short-description>
refactor/<short-description>
test/<short-description>
```

Examples:

```text
feature/http-check
feature/service-status
 docs/domain-model
```

## Commit style

Prefer concise Conventional Commit-style messages:

```text
feat: add HTTP service check
fix: preserve timeout failure reason
test: cover unexpected HTTP status
docs: add monitoring sequence diagram
refactor: isolate status classification
chore: configure CI
```

## Pull requests

Keep PRs focused. A PR should explain:

- what changed;
- why it changed;
- which Issue/User Story/Requirement it addresses;
- how the change was validated;
- relevant trade-offs or follow-up work.

## Gleam quality checks

Once implementation begins, source changes should normally pass:

```sh
gleam format
gleam test
```

Additional checks may be added when CI is introduced.

## Engineering documentation

- Product vision: `docs/vision.md`
- Requirements and business rules: `docs/requirements.md`
- Product backlog: `docs/backlog.md`
- Architecture: `docs/architecture.md`
- Domain model: `docs/domain.md`
- Diagrams: `docs/diagrams/`
- Architecture Decision Records: `docs/adr/`
