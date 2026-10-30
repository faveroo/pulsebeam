# Architecture

> Status: Stage 3 Monitoring Core completed. This document defines responsibility boundaries, not a frozen folder structure.

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

### Application

Coordinates use cases and workflows such as:
- registering/managing services;
- triggering monitoring checks;
- coordinating scheduling;
- querying history;
- calculating metrics;
- evaluating incident state transitions;
- Community workflows.

### Infrastructure

Provides replaceable technical mechanisms such as:
- HTTP client;
- persistence adapter;
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
          ^
          |
Infrastructure
  HTTP adapter / repositories / clocks / BEAM scheduler
```

The exact persistence technology must be documented through an ADR before implementation is coupled to a database or storage engine.

## Architecture diagram

See [Component Architecture](./diagrams/architecture.md).

## Monitoring interaction

See [Monitoring Check Sequence](./diagrams/monitoring-sequence.md) and [Main Flows](./diagrams/flows.md).

## Accepted architecture decisions

- [ADR-0001 — Use one Service model for Community and Private monitoring](./adr/0001-shared-service-model.md)
- [ADR-0002 — Keep monitoring checks separate from incidents](./adr/0002-separate-checks-from-incidents.md)

## Known technical debt entering Stage 4

- HTTP transport and timing are currently invoked directly from `service_check.gleam`;
- latency measurement currently uses system/wall-clock timestamps rather than a monotonic timer;
- `CheckHistory` is in-memory only;
- `ServiceId` needs a controlled persistence/reconstitution path;
- no scheduler, supervision topology, or restart recovery is implemented yet;
- private-history authorization remains outside the current core.

See [Stage 3 Review](./stage-3-review.md) for the full list.

## Decisions intentionally deferred

- exact persistence technology until the Stage 4 ADR;
- web framework;
- frontend technology;
- exact scheduler/process supervision topology until Stage 4 implementation validates the design;
- exact Health Score formula;
- incident failure/recovery thresholds;
- notification providers.

These decisions should be made when the associated requirement becomes relevant rather than prematurely.
