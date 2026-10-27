# Domain Model

> Status: Stage 2 baseline accepted. The model may evolve as implementation reveals new constraints.

## Core concepts

### Service

Represents a digital service or endpoint monitored by PulseBeam.

Current conceptual attributes:
- id
- owner_id (optional for Community-curated services)
- name
- url
- expected_status
- check_interval
- enabled
- visibility

PulseBeam uses one `Service` concept for both Community and Private monitoring. See [ADR-0001](./adr/0001-shared-service-model.md).

### Service visibility

Current values:
- `Community` — public service curated for the PulseBeam Community catalog.
- `Private` — endpoint visible only to its owner or authorized users.

`Unlisted` remains a future possibility and is outside the current scope.

### ServiceCheck

Represents one objective monitoring observation against a Service.

Current conceptual attributes:
- id
- service_id
- status
- http_status (optional)
- latency_ms (optional)
- checked_at
- error (optional)

### Service status

Initial model:
- `UP`
- `DOWN`

Potential states such as `DEGRADED` and `UNKNOWN` remain deferred until business rules justify them.

### Check error

Candidate domain variants:
- Timeout
- DnsError
- ConnectionError
- UnexpectedStatus(Int)
- InternalMonitoringError

The exact representation will be aligned with the selected Gleam HTTP/runtime libraries during implementation.

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

A service may be technically `UP` while Community reports indicate a localized or partial problem. PulseBeam presents both signals without conflating them.

## Diagrams

- [Domain/class diagram](./diagrams/domain-model.md)
- [Entity-relationship diagram](./diagrams/erd.md)
- [Use-case diagram](./diagrams/use-cases.md)
- [Monitoring sequence](./diagrams/monitoring-sequence.md)
- [Main flows](./diagrams/flows.md)

## Deferred decisions

The following are intentionally not frozen in Stage 2:
- exact incident threshold/consecutive-failure policy;
- minimum history required for Health Score;
- exact Health Score formula;
- scheduler/process topology on BEAM;
- persistence technology and retention policy.
