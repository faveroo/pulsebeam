# Architecture

> Status: Stage 2 baseline accepted. This document defines responsibility boundaries, not a frozen folder structure.

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
- Incident
- uptime and Health Score concepts
- Favorite, CommunityReport, and Comment rules

### Application

Coordinates use cases and workflows such as:
- registering/managing services;
- triggering monitoring checks;
- coordinating scheduling;
- calculating metrics;
- evaluating incident state transitions;
- Community workflows.

### Infrastructure

Provides replaceable technical mechanisms such as:
- HTTP client;
- persistence adapter;
- clock/timers;
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

## Architecture diagram

See [Component Architecture](./diagrams/architecture.md).

## Monitoring interaction

See [Monitoring Check Sequence](./diagrams/monitoring-sequence.md) and [Main Flows](./diagrams/flows.md).

## Accepted architecture decisions

- [ADR-0001 — Use one Service model for Community and Private monitoring](./adr/0001-shared-service-model.md)
- [ADR-0002 — Keep monitoring checks separate from incidents](./adr/0002-separate-checks-from-incidents.md)

## Decisions intentionally deferred

- persistence technology;
- web framework;
- frontend technology;
- exact scheduler/process supervision topology;
- exact Health Score formula;
- incident failure/recovery thresholds;
- notification providers.

These decisions should be made when the associated requirement becomes relevant rather than prematurely.
