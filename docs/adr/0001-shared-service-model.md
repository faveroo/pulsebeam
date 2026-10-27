# ADR-0001 — Use one Service model for Community and Private monitoring

## Status

Accepted

## Context

PulseBeam has two product contexts:

- Community services, which are public and curated for broad monitoring.
- Private services, which belong to an authenticated user through My PulseBeam.

Both contexts require the same core monitoring behavior: URL configuration, expected HTTP status, interval, enabled state, checks, historical metrics, and incidents.

Creating separate domain entities for public and private services would duplicate monitoring behavior and risk divergence between the two paths.

## Decision

PulseBeam will model both contexts through one `Service` domain concept.

The service context is distinguished by:

- `visibility`, initially `Community` or `Private`.
- optional ownership, where private services require an owner and Community services may be platform-curated.

Monitoring logic will operate on `Service` independently from how that service is presented in Community or My PulseBeam.

## Consequences

### Positive

- Monitoring logic is shared.
- Historical metrics and incidents use one model.
- Community and Private presentation concerns remain outside the Monitoring Engine.
- Less duplicated implementation and testing.

### Trade-offs

- Domain validation must enforce rules such as private services requiring an owner.
- Community-only features such as comments, reports, and favorites must validate service visibility.
- Authorization cannot be inferred only from the existence of a Service record.

## Alternatives considered

### Separate CommunityService and PrivateService entities

Rejected for now because both concepts share the same monitoring lifecycle and would introduce significant duplication before a domain difference justifies separate aggregates.
