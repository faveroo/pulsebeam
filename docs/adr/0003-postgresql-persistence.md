# ADR-0003 — Use PostgreSQL behind repository contracts

## Status

Accepted

## Context

Stage 3 introduced an in-memory monitoring core capable of registering services, executing HTTP checks, preserving check outcomes, querying history, and calculating uptime. Stage 4 requires that service configuration and monitoring history survive application restarts and remain queryable as the product grows.

PulseBeam is expected to evolve beyond a single-process prototype. The roadmap includes multiple monitored services, concurrent monitoring, historical queries by service and time range, authenticated private services, Community features, incidents, favorites, reports, and other relational data.

The persistence choice must therefore support:

- durable storage across application restarts;
- concurrent access from BEAM processes;
- efficient filtering of `ServiceCheck` records by `service_id` and time range;
- relational constraints between services and their historical checks;
- transactions and explicit failures;
- growth toward a multi-user web platform;
- isolation between domain rules and storage-specific concerns.

The current domain must not become coupled to a database client. Persistence technology is an infrastructure concern and should remain replaceable behind PulseBeam-owned repository contracts.

## Decision

PulseBeam will use PostgreSQL as its primary durable persistence technology.

The Gleam PostgreSQL client selected for the initial adapter is `pog`. Database connection pools belong to the infrastructure/runtime layer and may be integrated into the OTP supervision tree when the persistent runtime is implemented.

Domain modules must not import `pog`, PostgreSQL-specific types, SQL concerns, or database error types.

Persistence access will be exposed through PulseBeam-owned repository boundaries. The initial boundaries are:

- `ServiceRepository` for durable service configuration;
- `ServiceCheckRepository` for durable monitoring observations and historical queries.

Concrete PostgreSQL adapters will translate between database rows and domain values. Storage/client failures will be mapped to PulseBeam persistence errors before they cross the infrastructure boundary.

The intended dependency direction is:

```text
Domain
   ^
   |
Application
   |
   v
Repository contracts
   |
   v
Infrastructure adapters
   |
   v
pog
   |
   v
PostgreSQL
```

Repository contracts are documented in [`docs/persistence.md`](../persistence.md).

## Persistence errors

Persistence failures must be explicit and controlled. Initial error categories are expected to cover concerns such as:

- connection failure;
- query/storage failure;
- conflicting persisted data;
- invalid persisted data that cannot be reconstructed as a valid domain value.

The exact Gleam representation will be implemented in a later issue. PostgreSQL- or `pog`-specific error values must not leak into the domain API.

A persistence failure for one monitoring operation must not crash unrelated monitoring work.

## Retention policy

Automatic retention or deletion of historical `ServiceCheck` records is intentionally deferred.

Stage 4 will preserve durable history without inventing an arbitrary retention period such as 30, 90, or 365 days. A retention policy will be defined once product requirements and real storage growth are better understood.

This decision does not prevent repository queries from constraining a historical period.

## Consequences

### Positive

- PostgreSQL supports the relational and time-range queries expected by PulseBeam.
- The storage model can grow with My PulseBeam, Community, incidents, favorites, reports, and authentication-related data.
- Transactions and database constraints can protect durable state.
- A connection pool fits the future concurrent BEAM runtime.
- Repository boundaries keep the domain testable without a database.
- In-memory or test adapters can implement the same repository behavior for deterministic tests.
- PostgreSQL-specific implementation can evolve without changing core monitoring rules.

### Trade-offs

- PostgreSQL requires an external database service instead of a single embedded file.
- Deployment and local development require database configuration and migrations.
- Mapping between database rows and opaque domain types must be designed explicitly.
- Connection lifecycle, pooling, migrations, and operational failures become infrastructure responsibilities.
- Repository contracts introduce an additional abstraction layer compared with calling SQL directly from application code.

## Alternatives considered

### SQLite with `sqlight`

SQLite is a strong embedded option and supports SQL, transactions, durable single-file storage, and in-memory databases for testing. It would reduce operational complexity for a local or single-node application.

It was not selected as the primary production persistence because PulseBeam is being designed toward a continuously running, concurrent, multi-user monitoring platform. PostgreSQL gives the project a clearer growth path for concurrent workloads, relational expansion, and service-oriented deployment.

SQLite may still be useful in isolated tooling or tests if a future requirement justifies it, but application code must not depend on SQLite-specific behavior.

### ETS

ETS is well suited to fast in-memory state inside the BEAM, but ETS tables are not durable application storage across node restarts. It may be useful later as a runtime cache, but it cannot satisfy Stage 4 durability by itself.

### DETS

DETS provides disk-backed Erlang term storage without a separate database server. It is attractive for simple durable key/value workloads but provides a weaker fit for relational data, historical time-range queries, indexing needs, and the expected product growth of PulseBeam.

### Mnesia

Mnesia is a BEAM-native distributed database and could support replicated Erlang nodes. PulseBeam does not currently require distributed database replication, and adopting Mnesia now would introduce operational and modeling complexity before that need exists.

If PulseBeam later requires a distributed BEAM-native storage model, that requirement can trigger a new architecture decision.

### Direct database calls from domain/application modules

Rejected. Direct `pog` usage throughout the codebase would couple monitoring rules and application workflows to PostgreSQL details, make tests harder to isolate, and make later storage changes expensive.
