# Architecture

> Status: Stage 3 Monitoring Core completed. Stage 4 persistence direction accepted through ADR-0003. This document defines responsibility boundaries, not a frozen folder structure.

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
- `service_check.gleam` — HTTP execution, timestamp, latency, outcome preservation, and UP/DOWN classification;
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

## Architecture diagram

See [Component Architecture](./diagrams/architecture.md).

## Monitoring interaction

See [Monitoring Check Sequence](./diagrams/monitoring-sequence.md) and [Main Flows](./diagrams/flows.md).

## Accepted architecture decisions

- [ADR-0001 — Use one Service model for Community and Private monitoring](./adr/0001-shared-service-model.md)
- [ADR-0002 — Keep monitoring checks separate from incidents](./adr/0002-separate-checks-from-incidents.md)
- [ADR-0003 — Use PostgreSQL behind repository contracts](./adr/0003-postgresql-persistence.md)

## Known technical debt entering Stage 4

- HTTP transport and timing are currently invoked directly from `service_check.gleam`;
- latency measurement currently uses system/wall-clock timestamps rather than a monotonic timer;
- `CheckHistory` is in-memory only and is not durable storage;
- `ServiceId` needs a controlled persistence/reconstitution path;
- no PostgreSQL adapter or migrations are implemented yet;
- no scheduler, supervision topology, or restart recovery is implemented yet;
- private-history authorization remains outside the current core.

See [Stage 3 Review](./stage-3-review.md) for the full Stage 3 review and [Persistence Architecture](./persistence.md) for the Stage 4 persistence boundary.

## Decisions intentionally deferred

- exact SQL schema details and migration tooling until the concrete PostgreSQL adapter is implemented;
- ServiceCheck retention/cleanup policy until storage growth and product requirements justify a policy;
- web framework;
- frontend technology;
- exact scheduler/process supervision topology until Stage 4 implementation validates the design;
- exact Health Score formula;
- incident failure/recovery thresholds;
- notification providers.

These decisions should be made when the associated requirement becomes relevant rather than prematurely.
