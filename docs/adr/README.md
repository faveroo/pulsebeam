# Architecture Decision Records (ADRs)

Use this directory for decisions that materially affect PulseBeam architecture and are likely to need historical context later.

Suggested naming:

```text
0001-short-decision-title.md
0002-another-decision.md
```

Suggested structure:

```markdown
# ADR-0001 — Decision title

## Status
Proposed | Accepted | Superseded | Rejected

## Context
What problem or constraint led to this decision?

## Decision
What did we decide?

## Consequences
What becomes easier, harder, or constrained because of this decision?

## Alternatives considered
What other reasonable options were evaluated?
```

Do not create an ADR for every implementation detail. Use ADRs for decisions such as persistence strategy, process/supervision model, public/private service modeling, API boundaries, and other long-lived architectural choices.
