# Persistence Architecture

> Status: Stage 4 baseline for Issue #14. This document defines persistence boundaries and expected behavior. It is not a concrete PostgreSQL implementation.

## Purpose

Stage 4 introduces durable monitoring state. PulseBeam must preserve registered services and monitoring history across application restarts without coupling the domain to PostgreSQL or a specific database client.

The selected durable storage is PostgreSQL, accessed by an infrastructure adapter using `pog`. See [ADR-0003](./adr/0003-postgresql-persistence.md).

## Dependency rule

Persistence is an infrastructure concern.

```text
Domain
  Service / ServiceCheck / Uptime
          ^
          |
Application
  use cases and monitoring workflows
          |
          v
Repository contracts
          |
          v
Infrastructure
  PostgreSQL adapters
          |
          v
pog
          |
          v
PostgreSQL
```

The following rules apply:

- domain modules must not import `pog`;
- domain modules must not contain SQL;
- domain types must not expose PostgreSQL-specific values;
- database rows are converted to domain values at the infrastructure boundary;
- invalid persisted data must fail explicitly instead of silently creating an invalid domain object;
- storage errors must be converted to PulseBeam persistence errors before returning to application workflows.

## Repository boundaries

PulseBeam starts with two repository responsibilities rather than one generic database abstraction.

### ServiceRepository

Responsible for durable service configuration.

Required Stage 4 capabilities:

- store a new `Service`;
- update an existing `Service` configuration/state;
- find a Service by `ServiceId`;
- list persisted Services needed by the monitoring runtime;
- preserve the original `ServiceId` when reconstructing a persisted Service;
- distinguish a missing Service from a persistence failure.

Conceptual contract:

```text
ServiceRepository
├── save(Service)
├── find_by_id(ServiceId)
└── list()
```

The exact Gleam function/type representation will be decided during implementation. This document defines behavior, not a required syntax.

The repository must preserve at least:

```text
Service
├── id
├── name
├── url
├── expected_status
├── interval_seconds
├── enabled
└── visibility
```

Future ownership fields can extend the persistence model when private-service authentication becomes part of the active milestone.

### ServiceCheckRepository

Responsible for durable monitoring observations.

Required Stage 4 capabilities:

- store one completed `ServiceCheck`;
- query checks for one Service;
- constrain history queries by time period;
- preserve a documented chronological order;
- preserve HTTP status when available;
- preserve latency when available;
- preserve failure reason when present;
- distinguish missing optional data from real zero/default values.

Conceptual contract:

```text
ServiceCheckRepository
├── store(ServiceCheck)
├── for_service(ServiceId)
└── between(ServiceId, from, to)
```

The Stage 3 in-memory `CheckHistory` may remain useful for pure domain tests, but it is not the durable source of truth for Stage 4.

## Query ordering

Historical repository queries should return an explicitly documented order. The Stage 3 history API currently exposes newest checks first, so the initial PostgreSQL adapter should preserve **newest-first** ordering unless a later requirement deliberately changes the public contract.

In SQL terms, the expected query shape will naturally support an index on service and check time, for example conceptually:

```text
(service_id, checked_at)
```

Exact schema and migration definitions belong to later Stage 4 implementation issues.

## Persistence errors

Infrastructure-specific failures must be translated to a small PulseBeam-owned error model.

Initial categories:

```text
PersistenceError
├── ConnectionFailed
├── QueryFailed
├── Conflict
└── InvalidPersistedData
```

These names are architectural guidance; the exact Gleam type can evolve during implementation if the concrete adapter exposes a meaningful distinction that the application must handle.

### ConnectionFailed

Used when the persistence service cannot be reached or a usable database connection cannot be obtained.

### QueryFailed

Used when a storage operation fails for a reason that is not safely represented by a more specific application-level category.

### Conflict

Used when durable state violates an expected uniqueness or concurrency constraint, such as a conflicting identifier.

### InvalidPersistedData

Used when a row exists but cannot be safely reconstructed into a valid domain value.

Examples include an invalid `ServiceId`, unsupported visibility value, or data that violates required domain invariants.

## Failure isolation

Persistence failures must be represented as values and handled by the application/runtime layer.

A failed write for one Service or ServiceCheck must not terminate unrelated monitors. Stage 4 scheduling and supervision will build on this rule.

```text
Monitor A -> persistence failure -> controlled error/reporting
Monitor B -> continues independently
Monitor C -> continues independently
```

The repository layer must not rely on application-wide crashes as normal error handling.

## Domain reconstruction

New domain entities and persisted entities have different identity lifecycles.

For a new Service:

```text
new Service -> generate UUID v7 -> persist same ID
```

For a persisted Service:

```text
row -> validate persisted ID -> reconstruct Service with original ID
```

Loading an existing Service must never call the new-Service path and generate a replacement identifier. The controlled `ServiceId` reconstruction API is tracked separately by Stage 4 Issue #15.

## Initial relational shape

This is a conceptual model only. Exact SQL types, constraints, migrations, and adapter code belong to later issues.

```text
services
├── id                 primary identity
├── name
├── url
├── expected_status
├── interval_seconds
├── enabled
├── visibility
├── created_at
└── updated_at

service_checks
├── id                 persistence identity if required
├── service_id          reference -> services
├── checked_at
├── status
├── http_status         optional
├── latency_ms          optional
└── error_reason        optional
```

The database representation may use PostgreSQL UUID or text-compatible forms as long as the adapter preserves the domain `ServiceId` contract. The exact choice is deferred to the concrete persistence implementation.

## Transactions and consistency

Repositories should use database transactions when a use case requires multiple persistence operations to succeed atomically.

Stage 4 does not require wrapping every single independent insert or query in an application-level transaction abstraction. Transaction boundaries should follow use-case consistency requirements rather than database convenience.

## Testing strategy

Repository contracts allow storage behavior to be tested separately from domain logic.

The intended layers are:

- pure domain tests without PostgreSQL;
- repository contract/adapter tests against isolated test persistence;
- integration tests covering PostgreSQL, monitoring runtime, restart recovery, and scheduling;
- no dependency on unstable public HTTP endpoints for tests that only verify persistence behavior.

An in-memory fake repository can be used where useful, but it must model the same observable behavior expected from the concrete repository contract.

## Retention and cleanup

No automatic `ServiceCheck` retention period is defined in Stage 4.

Historical data will be retained until product requirements and real storage growth provide enough information to choose a policy. Cleanup jobs, archival, partitioning, and time-based deletion are therefore intentionally deferred.

This decision should be revisited before historical volume becomes an operational concern.

## Out of scope for Issue #14

This architecture issue does not implement:

- the `pog` dependency;
- PostgreSQL connection configuration;
- database migrations;
- concrete repository modules;
- SQL queries;
- Docker/database development environment;
- Service reconstruction code;
- scheduler behavior;
- retention jobs.

Those concerns belong to subsequent Stage 4 issues.
