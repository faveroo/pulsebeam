# ADR-0002 — Keep monitoring checks separate from incidents

## Status

Accepted

## Context

A `ServiceCheck` represents one observation at one point in time. An `Incident` represents a meaningful period in which a service is considered unhealthy or unavailable.

Treating every failed check as a full incident would tightly couple low-level network observations to a higher-level operational event and make it difficult to later add policies such as consecutive failures, recovery thresholds, or transient-failure suppression.

## Decision

PulseBeam will model `ServiceCheck` and `Incident` as separate concepts.

A check records objective monitoring evidence such as:

- resulting status;
- HTTP status when available;
- latency when available;
- error reason;
- check timestamp.

An incident is opened, maintained, or resolved by evaluating state transitions and an incident policy over checks.

The exact incident threshold policy is intentionally deferred until later modeling/implementation work.

## Consequences

### Positive

- Historical checks remain faithful raw monitoring observations.
- Incident policy can evolve without rewriting check history.
- Transient failures can later be distinguished from operational incidents.
- Recovery can be represented explicitly.

### Trade-offs

- Incident management adds an additional application/domain workflow.
- Queries may need to combine checks and incidents for a complete timeline.

## Alternatives considered

### Create one incident for every DOWN check

Rejected because a single failed request may represent transient network noise rather than a meaningful service outage.
