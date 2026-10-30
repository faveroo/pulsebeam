# Domain Model

> Status: Stage 3 implementation baseline completed. The model may evolve as persistence and runtime concerns are introduced.

## Core concepts

### Service

Represents a digital service or endpoint monitored by PulseBeam.

Current implemented attributes:
- `id: ServiceId`
- `name`
- `url`
- `expected_status`
- `interval_seconds`
- `enabled`
- `visibility`

`ServiceId` is an opaque UUID v7-backed identifier generated when a new Service is created.

PulseBeam uses one `Service` concept for both Community and Private monitoring. See [ADR-0001](./adr/0001-shared-service-model.md).

`owner_id` remains a future attribute for authenticated/private-service ownership and is not yet implemented.

### Service visibility

Current values:
- `Community` — public service curated for the PulseBeam Community catalog.
- `Private` — endpoint intended to be visible only to its owner or authorized users once authentication/authorization is implemented.

`Unlisted` remains a future possibility and is outside the current scope.

### ServiceCheck

Represents one objective monitoring observation against a Service.

Current implemented attributes:
- `service_id`
- `checked_at`
- `latency_ms` (optional)
- `outcome`
- `status`

`ServiceCheck` currently has no independent check identifier. A persisted check ID may be introduced in Stage 4 if required by the selected storage model.

### ServiceCheck outcome

Current variants:
- `HttpResponse(Int)` — an HTTP response was received and its status code is preserved.
- `Failure(ServiceCheckError)` — the check failed before a usable HTTP response was available.

Keeping outcome separate from final health status allows PulseBeam to represent, for example, `Down` together with `HttpResponse(500)` rather than losing the actual response.

### Service status

Current implemented values:
- `Up`
- `Down`

Potential states such as `Degraded` and `Unknown` remain deferred until business rules justify them.

### Check error

Current implemented variants:
- `Timeout`
- `ConnectionFailed`
- `InvalidRequest`
- `InvalidResponse`

Unexpected valid HTTP statuses are not transport errors. They remain `HttpResponse(status)` outcomes and can produce `Down` when the received status differs from the Service's configured expected status.

### CheckHistory

Represents the Stage 3 in-memory collection of ServiceChecks.

Current behavior:
- immutable storage;
- newest check first;
- latest-check lookup;
- filtering by `ServiceId`;
- inclusive filtering between two timestamps.

This is intentionally an in-memory implementation. Stage 4 introduces a durable repository/persistence boundary.

### Uptime

Current variants:
- `Available(Float)`
- `NotAvailable`

Uptime is calculated as:

```text
UP checks / total considered checks * 100
```

Supported periods:
- last 24 hours;
- last 7 days;
- last 30 days.

A period returns `NotAvailable` when history does not reach the beginning of the requested window, preventing PulseBeam from presenting an assumed 100% based only on a short failure-free history.

### User

Represents an authenticated PulseBeam user. A user can own private services and, in later milestones, favorite Community services, report possible failures, and comment.

### Favorite

Associates a user with a Community service they want to follow.

### CommunityReport

Represents a user's report that a public service may be experiencing problems. Community reports remain independent from automated technical status.

### Comment

Represents Community discussion attached to a public service.

### Incident

Represents a meaningful period of service unavailability or unhealthy operation. Incidents are intentionally distinct from individual checks. See [ADR-0002](./adr/0002-separate-checks-from-incidents.md).

### HealthSnapshot

Represents a historical Health Score observation for a defined period if PulseBeam chooses to persist scores. The exact persistence strategy and formula remain deferred.

## Important domain separation

```text
Automated monitoring data != Community perception
```

A service may be technically `Up` while Community reports indicate a localized or partial problem. PulseBeam presents both signals without conflating them.

## Stage 4 domain considerations

Persistence introduces several requirements that should not weaken the domain model:
- persisted Services must retain their existing `ServiceId` after restart;
- loading a Service must not generate a new UUID;
- storage-specific IDs and serialization details should remain outside business rules where practical;
- metrics must be calculated from checks already scoped to the intended service;
- check history persistence must preserve timestamp, final status, outcome, latency, and service reference.

## Diagrams

- [Domain/class diagram](./diagrams/domain-model.md)
- [Entity-relationship diagram](./diagrams/erd.md)
- [Use-case diagram](./diagrams/use-cases.md)
- [Monitoring sequence](./diagrams/monitoring-sequence.md)
- [Main flows](./diagrams/flows.md)

## Deferred decisions

The following remain intentionally open:
- persisted `ServiceCheck` identifier strategy;
- exact incident threshold/consecutive-failure policy;
- minimum history required for Health Score;
- exact Health Score formula;
- scheduler/process topology on BEAM;
- persistence technology and retention policy until the Stage 4 ADR;
- authentication/authorization model for private-service history.
