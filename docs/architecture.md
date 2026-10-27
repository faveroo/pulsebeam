# Architecture

> Status: initial draft. Detailed architecture will be defined during Stage 2 — Modeling.

## Architectural direction

PulseBeam will evolve around a shared Monitoring Engine used by both public Community services and private My PulseBeam endpoints.

```text
                    PulseBeam
                       |
             Monitoring Engine
                       |
          +------------+------------+
          |                         |
   Community Services         Private Services
```

## Initial responsibility boundaries

The project should keep the following concerns distinguishable as it evolves:

- **Domain** — services, checks, status, metrics, incidents, and business rules.
- **Application** — monitoring use cases, scheduling coordination, metric calculation, and workflows.
- **Infrastructure** — HTTP client, persistence, clocks/timers, external notification providers.
- **Interfaces** — CLI initially; API/web interfaces in later milestones.

This is a direction rather than a frozen folder structure. The implementation should remain simple until a boundary is justified by actual behavior.

## Core runtime goals

- Use Gleam as the primary implementation language.
- Explore BEAM concurrency for independent monitoring processes.
- Isolate failures between unrelated service checks.
- Keep automated monitoring data independent from Community reports.
- Avoid coupling private and Community presentation rules to the monitoring engine.

## Planned architecture work

Stage 2 will define:

1. Domain model.
2. Use-case diagram.
3. Component/architecture diagram.
4. Check sequence diagram.
5. Data model / ER diagram.
6. Main flows and state transitions.
7. Initial architecture decisions (ADRs when appropriate).

## Decisions not yet frozen

- Persistence technology.
- Web framework.
- Frontend technology.
- Exact scheduler/process topology.
- Health Score formula.
- Notification providers.

These decisions should be made when the associated requirement becomes relevant rather than prematurely.
