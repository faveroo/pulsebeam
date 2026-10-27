# Domain Model

> Status: initial notes. The definitive domain model will be produced during Stage 2 — Modeling.

## Initial concepts

### Service

Represents a digital service or endpoint monitored by PulseBeam.

Candidate attributes:
- id
- owner_id (optional for Community-owned services)
- name
- url
- expected_status
- interval
- enabled
- visibility

### Service visibility

Initial conceptual values:
- `Community` — public service curated for the PulseBeam Community catalog.
- `Private` — endpoint visible only to its owner or authorized users.

An `Unlisted` visibility mode may be evaluated in the future, but is not part of the current v1.0 scope.

### Check

Represents one monitoring attempt against a Service.

Candidate attributes:
- id
- service_id
- status
- http_status
- latency
- checked_at
- error

### Service status

Initial model:
- `UP`
- `DOWN`

Potential future states such as `DEGRADED` and `UNKNOWN` are intentionally deferred until clear business rules exist.

### Check error

Candidate domain variants:
- Timeout
- DnsError
- ConnectionError
- UnexpectedStatus(Int)
- InternalMonitoringError

The exact representation will be decided after examining the HTTP libraries and runtime behavior available in Gleam.

### User

Represents an authenticated PulseBeam user. Users can own private services and later favorite Community services, report failures, and comment.

### Favorite

Links a user to a Community service they want to follow.

### Community report

Represents a user's report that a public service may be experiencing problems. Reports do not directly override automated technical status.

### Comment

Represents user discussion attached to a Community service.

### Incident

Represents a meaningful availability event detected from monitoring state transitions. The exact rules for opening and resolving incidents remain to be modeled.

### Health Score

A derived value from 0 to 100 based on objective historical monitoring data. The formula is deliberately not defined yet.

## Important domain separation

```text
Automated monitoring data != Community perception
```

A service may be technically classified as `UP` while Community reports indicate a localized or partial problem. PulseBeam must be capable of presenting both without conflating them.

## Next modeling questions

- Is Service one aggregate for Community and Private monitoring, or should ownership/visibility be modeled separately?
- Should a check store a final status or derive it from response/error data?
- How should incidents be opened and resolved from consecutive checks?
- What amount of history is sufficient before uptime or Health Score is considered meaningful?
- How should the scheduler represent per-service intervals on BEAM?
