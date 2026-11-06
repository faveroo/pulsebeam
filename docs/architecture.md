# Architecture

> Status: Stage 3 Monitoring Core completed. Stage 4 PostgreSQL persistence implemented through Issues #16 and #17. Issue #18 adds replaceable HTTP/clock boundaries and monotonic latency timing; runtime scheduling, supervision, and restart recovery remain pending. This document defines responsibility boundaries, not a frozen folder structure.

## Architectural direction

PulseBeam uses one shared Monitoring Engine for both public Community services and private My PulseBeam endpoints.

```text
                    PulseBeam
                       |
             Monitoring Engine
                       |
          +------------+------------+
          |                         |
   Community Services         Private Services
```

## Responsibility boundaries

### Domain

Owns concepts and business rules such as:
- Service
- ServiceCheck
- status classification
- uptime and future Health Score concepts
- Incident
- Favorite, CommunityReport, and Comment rules

Domain modules do not know about PostgreSQL, `pog`, SQL queries, connection pools, or storage-specific error types.

### Application

Coordinates use cases and workflows such as:
- registering/managing services;
- triggering monitoring checks;
- coordinating scheduling;
- querying history;
- calculating metrics;
- evaluating incident state transitions;
- Community workflows.

Application workflows consume persistence through PulseBeam-owned repository boundaries rather than calling a database client directly.

### Infrastructure

Provides replaceable technical mechanisms such as:
- HTTP client;
- PostgreSQL persistence adapters;
- `pog` connection pool and database access;
- system clock and monotonic timer;
- scheduler/BEAM process integration;
- notification providers in future milestones.

### Interfaces

Expose application capabilities through:
- CLI in the initial development phase;
- HTTP API in a later milestone;
- Web UI after the API/platform layer exists.

## Core runtime goals

- Gleam is the primary implementation language.
- BEAM concurrency should allow independent monitoring work.
- Failure in one service check must not terminate unrelated checks.
- Automated monitoring and Community reports remain independent signals.
- Public/private presentation and authorization rules must not be embedded in low-level HTTP monitoring logic.
- Domain classification and metric rules should remain testable without real network calls.
- Persistence must not leak storage-specific concerns into core domain types.
- A persistence failure in one monitoring flow must not terminate unrelated monitoring work.

## Stage 3 implementation snapshot

Stage 3 introduced four core modules:

- `service.gleam` — service identity, validation, visibility, and enabled state;
- `service_check.gleam` — originally combined HTTP execution, timing, and UP/DOWN classification; Issue #18 moved external effects into adapters while retaining pure classification and outcome preservation in the domain;
- `check_history.gleam` — immutable in-memory history and time/service filtering;
- `uptime.gleam` — uptime calculation and 24h/7d/30d period rules.

The complete review is recorded in [Stage 3 Review](./stage-3-review.md).

## Stage 4 architectural objective

Stage 4 introduces **Persistent Monitoring**. The main architectural change is to separate the Stage 3 domain rules from replaceable infrastructure so that PulseBeam can persist state and run monitoring continuously.

Target direction:

```text
Domain
  Service / ServiceCheck / Uptime rules
          ^
          |
Application
  register / monitor / query / schedule use cases
          |
          v
Repository contracts
          |
          v
Infrastructure
  PostgreSQL adapters / HTTP adapter / clocks / BEAM scheduler
          |
          v
PostgreSQL via pog
```

PostgreSQL is the selected primary durable persistence technology. `pog` is the selected Gleam PostgreSQL client for the initial infrastructure adapter. See [ADR-0003](./adr/0003-postgresql-persistence.md).

Detailed repository responsibilities, persistence errors, reconstruction rules, and retention decisions are documented in [Persistence Architecture](./persistence.md).

## Persistence boundaries

PulseBeam starts with two explicit repository responsibilities:

- `ServiceRepository` — durable Service configuration, lookup, listing, and updates;
- `ServiceCheckRepository` — durable ServiceCheck storage and historical queries.

These are application/infrastructure boundaries, not generic database abstractions. Their purpose is to keep PostgreSQL and `pog` outside the core domain while expressing the persistence capabilities the application actually requires.

The PostgreSQL adapter is responsible for:

- executing SQL;
- decoding database rows;
- reconstructing valid domain values;
- mapping database/client failures to PulseBeam persistence errors;
- preserving original Service identity when loading persisted records.

## HTTP and clock boundaries (Issue #18)

Monitoring check execution now uses explicit, replaceable Gleam function-record ports:

- `monitoring/ports.gleam` declares `HttpTransport(get: fn(String) -> Result(Int, ServiceCheckError))` and `Clock(now: fn() -> Timestamp, monotonic_ms: fn() -> Int)`.
- `monitoring/checker.gleam` orchestrates a check through these ports. It captures `checked_at` from wall-clock time and measures successful request latency by subtracting monotonic readings.
- `service_check.from_result()` converts the HTTP result into a `ServiceCheck`, classifying a received HTTP status against the Service's configured expected status. A transport failure becomes `Failure(reason)`, `Down`, and `latency_ms: None`.
- `infrastructure/http/transport.gleam` performs real HTTP with `gleam/httpc`, mapping transport errors into domain-owned `ServiceCheckError` values. An HTTP error status such as 503 is still an `Ok(503)` transport result; the domain classifies it separately.
- `infrastructure/clock/system.gleam` supplies `timestamp.system_time` for calendar time and a small Erlang FFI adapter (`src/pulsebeam_clock_ffi.erl`) around `erlang:monotonic_time(millisecond)` for elapsed time.
- `monitoring/live.gleam` composes the concrete adapters. Callers use `live.run(service)` for real checks or inject fake ports into `checker.run` for deterministic tests.

```text
monitoring/live.run(service)
  └── monitoring/checker.run(service, transport, clock)
        ├── Clock.now()                   -> checked_at
        ├── Clock.monotonic_ms()          -> start
        ├── HttpTransport.get(url)        -> Result(Int, ServiceCheckError)
        ├── Clock.monotonic_ms()          -> finish
        └── service_check.from_result()   -> domain ServiceCheck

Concrete adapters: infrastructure/http/transport + infrastructure/clock/system
```

The domain does not import `gleam/httpc`, HTTP request builders, or a system clock. HTTP error mapping stays at the infrastructure boundary; classification stays in the domain.

Unit tests in `test/service_check_test.gleam` and `test/monitoring_checker_test.gleam` run without network access or actual elapsed time. Infrastructure tests use `test/support/pulsebeam_http_server_ffi.erl` to serve HTTP responses on loopback without internet access, plus a separate clock test. The real HTTP integration suite still assumes port `127.0.0.1:1` refuses connections in one failure test; making that condition fully controlled is a possible test-hardening follow-up.

## Architecture diagram

See [Component Architecture](./diagrams/architecture.md).

## Monitoring interaction

See [Monitoring Check Sequence](./diagrams/monitoring-sequence.md) and [Main Flows](./diagrams/flows.md).

## Accepted architecture decisions

- [ADR-0001 — Use one Service model for Community and Private monitoring](./adr/0001-shared-service-model.md)
- [ADR-0002 — Keep monitoring checks separate from incidents](./adr/0002-separate-checks-from-incidents.md)
- [ADR-0003 — Use PostgreSQL behind repository contracts](./adr/0003-postgresql-persistence.md)

## Known technical debt entering Stage 4

- The original `CheckHistory` implementation remains in-memory; durable history is provided separately through `ServiceCheckRepository`;
- Service and ServiceCheck adapters exist, but application-level repository composition and supervised pool lifecycle are not yet implemented;
- integration tests currently create per-test PostgreSQL pools without explicit teardown (see [Persistence Architecture](./persistence.md#technical-debt-and-follow-up));
- no scheduler, supervision topology, or restart recovery is implemented yet;
- private-history authorization remains outside the current core.

See [Stage 3 Review](./stage-3-review.md) for the full Stage 3 review and [Persistence Architecture](./persistence.md) for the Stage 4 persistence boundary.

## Decisions intentionally deferred

- automated migration tooling (the concrete SQL schemas and manual migrations now exist);
- ServiceCheck retention/cleanup policy until storage growth and product requirements justify a policy;
- web framework;
- frontend technology;
- exact scheduler/process supervision topology until Stage 4 implementation validates the design;
- exact Health Score formula;
- incident failure/recovery thresholds;
- notification providers.

These decisions should be made when the associated requirement becomes relevant rather than prematurely.
