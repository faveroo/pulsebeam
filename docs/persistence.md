# Persistence Architecture

> Status: Stage 4 persistence architecture (ADR-0003). The PostgreSQL `ServiceRepository` and `ServiceCheckRepository` adapters are implemented through Issues #16 and #17. Issue #19 integrates scheduler/runtime startup and persistence on each check; OTP supervision and automatic process recovery are future work.

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

Implemented adapter operations:

```text
ServiceRepository
├── insert(Service)
├── update(Service)
├── find_by_id(ServiceId) -> Result(Option(Service), PersistenceError)
└── list() -> Result(List(Service), PersistenceError)
```

The PostgreSQL adapter receives a `pog.Connection` in addition to each operation's domain inputs. The independent repository contract lives in `src/pulsebeam/repository/service_repository.gleam`; application-level wiring of a concrete adapter remains separate from the domain.

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

Implemented adapter operations:

```text
ServiceCheckRepository
├── store(ServiceCheck) -> Result(Nil, PersistenceError)
├── for_service(ServiceId) -> Result(List(ServiceCheck), PersistenceError)
└── between(ServiceId, from, to) -> Result(List(ServiceCheck), PersistenceError)
```

The adapter lives in `src/pulsebeam/infrastructure/postgres/service_check_repository.gleam`, accepts a `pog.Connection`, and reconstructs domain `ServiceCheck` values at the persistence boundary.

The Stage 3 in-memory `CheckHistory` may remain useful for pure domain tests, but it is not the durable source of truth for Stage 4.

## Query ordering and time windows

Both `for_service` and `between` return checks **newest first** with `ORDER BY checked_at DESC, id DESC`. The database-generated identity column is a deterministic tie-breaker when two checks share the same timestamp. `between` uses inclusive boundaries (`checked_at >= from AND checked_at <= to`); no matching checks return `Ok([])`.

The concrete migration `db/migrations/0002_create_service_checks.sql` creates `idx_service_checks_history` on `(service_id, checked_at DESC, id DESC)` to support these access patterns.

## Persistence errors

Infrastructure-specific failures must be translated to a small PulseBeam-owned error model.

Initial categories:

```text
PersistenceError
├── ConnectionFailed
├── QueryFailed
├── Conflict
├── InvalidPersistedData
└── NotFound
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

### NotFound

Used when an update targets a Service that does not exist. A lookup with no match instead returns `Ok(None)` for Services or `Ok([])` for check history.

The current ServiceCheck adapter maps unavailable connections to `ConnectionFailed`, decoding/reconstruction failures to `InvalidPersistedData`, and other PostgreSQL/query failures to `QueryFailed`.

## Failure isolation

Persistence failures must be represented as values and handled by the application/runtime layer.

A failed write for one Service or ServiceCheck must not terminate unrelated monitors. The Stage 4 runtime already isolates each Service and sends a completion signal after successful or failed persistence, allowing the scheduler to continue. Unexpected BEAM process crashes still require automatic recovery in a later issue.

```text
Monitor A -> persistence failure -> controlled error/reporting
Monitor B -> continues independently
Monitor C -> continues independently
```

The repository layer must not rely on application-wide crashes as normal error handling.

## Domain reconstruction and representation

New Services receive UUID v7 identities; persisted Services are reconstructed from their original, validated `ServiceId` without generating a replacement.

ServiceCheck persistence preserves the existing domain sum type:

- `HttpResponse(code)` maps to `http_status = code` and `error_reason = NULL`.
- `Failure(Timeout | ConnectionFailed | InvalidRequest | InvalidResponse)` maps to `http_status = NULL` and one of `timeout`, `connection_failed`, `invalid_request`, `invalid_response` in `error_reason`.
- `latency_ms` is nullable; SQL `NULL` becomes `None` rather than `Some(0)`.
- `Up` and `Down` map to `up` and `down` in the status column.
- `service_id` is stored as PostgreSQL UUID. The adapter converts it to validated `ServiceId` at load time.
- `checked_at` is stored as `TIMESTAMPTZ`. Writes and time-window parameters use `pog.timestamp`; reads select `(EXTRACT(EPOCH FROM checked_at) * 1000000)::bigint` and decode it with `pog.timestamp_decoder()` to preserve microsecond timestamps.

The `CheckRow` decoder converts columns into an intermediate record before `row_to_check` reconstructs the domain value. Unsupported status/error strings, malformed combinations of response/error columns, invalid identifiers, and a `Failure` marked `Up` produce `InvalidPersistedData` instead of silently generating an invalid check.

## Implemented relational schema

The authoritative migrations are:

- [`0001_create_services.sql`](../db/migrations/0001_create_services.sql): `services` configuration and UUID primary key.
- [`0002_create_service_checks.sql`](../db/migrations/0002_create_service_checks.sql): durable check history.

The `service_checks` table contains:

| Column | PostgreSQL type | Notes |
| --- | --- | --- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Database primary key; not part of domain `ServiceCheck` |
| `service_id` | `UUID NOT NULL` | Foreign key to `services(id)` |
| `checked_at` | `TIMESTAMPTZ NOT NULL` | Time of observation |
| `status` | `TEXT NOT NULL` | Restricted to `up` or `down` |
| `http_status` | `INTEGER NULL` | When present, 100 through 599 |
| `latency_ms` | `INTEGER NULL` | Nonnegative when present |
| `error_reason` | `TEXT NULL` | Restricted to the four domain failure codes |

Database constraints require **exactly one** of `http_status` and `error_reason` to be non-null, and prevent a recorded failure from having status `up`. The foreign key does not cascade deletion of check history. This schema is for Stage 4; future migrations may extend it as product requirements evolve.

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

Issue #17 integration tests cover HTTP and failure persistence, all failure reasons, full domain round-trips, inclusive time windows, service isolation, empty results, and deterministic ordering for identical timestamps. Tests use the dedicated `pulsebeam_test` PostgreSQL database and transaction rollbacks; see [Local Development](./development.md) for setup.

## Technical debt and follow-up

### PostgreSQL pool lifecycle and test isolation

`test/support/postgres.gleam` currently starts a **new named `pog` pool for each integration test**, with `pool_size = 1` and readiness polling. Queries return their connection to the pool, but finishing a query does **not** explicitly stop the pool. The current helper does not tear pools down after tests.

An intermittent EUnit/`pgo` timeout was observed when the suite grew; limiting pool size coincided with successful subsequent runs. **The root cause was not proven**, so this is a resource-lifecycle risk to investigate rather than a confirmed connection-exhaustion defect.

Follow-up work (appropriate for the Stage 4 integration/runtime infrastructure work, including Issue #23):

- Provide supervised, application-owned pool startup/shutdown rather than one pool per check or test in production.
- Use a managed/shared test pool or explicit pool cleanup, preserving each test's independent rollback transaction.
- Add connection-count/concurrency monitoring and test-run timeout diagnostics.
- Make test database provisioning and integration-test execution reproducible in CI, separate from pure domain tests.

### Persistence diagnostics and boundaries

The ServiceCheck adapter maps unclassified SQL failures, including foreign-key violations, to `QueryFailed`. Consider more specific error mappings if application workflows need to distinguish missing parent Services or particular constraints; do not leak `pog` errors into the domain.

The runtime bootstrap composes the concrete PostgreSQL Service and ServiceCheck adapters, but not all repository contract function records are wired through a separate application service. The running application reports persistence success/failure without a ServiceId in each outcome; structured per-Service diagnostics remain future work.

## Retention and cleanup

No automatic `ServiceCheck` retention period is defined in Stage 4.

Historical data will be retained until product requirements and real storage growth provide enough information to choose a policy. Cleanup jobs, archival, partitioning, and time-based deletion are therefore intentionally deferred.

This decision should be revisited before historical volume becomes an operational concern.

## Historical scope of Issue #14

The original architecture-only Issue #14 did not implement the items below. Some have since been delivered in Issues #15–#17; this list is retained as historical context rather than a statement of current functionality:


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
