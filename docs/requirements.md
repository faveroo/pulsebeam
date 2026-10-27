# Requirements

This document records the functional requirements, non-functional requirements, and initial business rules for PulseBeam.

## Functional requirements

### Monitoring core

- **RF01** — The system must allow a service to be registered for monitoring.
- **RF02** — A service must contain at least a name, URL, expected HTTP status, and check interval.
- **RF03** — The system must perform HTTP checks periodically.
- **RF04** — The system must record the returned HTTP status code.
- **RF05** — The system must measure and record response time.
- **RF06** — The system must classify each check as `UP` or `DOWN`.
- **RF07** — The system must record the date and time of each check.
- **RF08** — The system must preserve communication errors that occur during checks.
- **RF09** — The system must allow monitoring to be disabled without deleting previous history.
- **RF10** — The system must support monitoring multiple services concurrently.

### History and metrics

- **RF11** — The system must store the history of checks.
- **RF12** — The system must allow the history of a service to be queried.
- **RF13** — The system must calculate service availability percentage.
- **RF14** — The system must calculate average latency.
- **RF15** — The system must calculate metrics for relevant periods such as 24 hours, 7 days, and 30 days.
- **RF16** — Historical data must be available for graphical representation.
- **RF17** — The system must calculate a Health Score for each service.
- **RF18** — The system must make historical Health Score data available.

### Public and private services

- **RF19** — Authenticated users must be able to create private endpoints.
- **RF20** — A private endpoint must only be accessible to its owner or explicitly authorized users in future versions.
- **RF21** — The system must maintain a public Community catalog.
- **RF22** — Public services must be viewable without authentication.
- **RF23** — The system must distinguish Community services from private services.
- **RF24** — Private services must not appear in public searches, rankings, or public pages.

### Users

- **RF25** — The system must support user registration.
- **RF26** — The system must support authentication.
- **RF27** — Authenticated users must have a `My PulseBeam` area.
- **RF28** — Users must be able to view their private services.
- **RF29** — Users must be able to edit permitted settings for their own services.

### Favorites

- **RF30** — Authenticated users must be able to favorite a public service.
- **RF31** — Users must be able to remove a service from favorites.
- **RF32** — Users must be able to view their favorite services.

### Incidents and alerts

- **RF33** — The system must detect when a monitored service becomes unavailable.
- **RF34** — The system must detect when a service returns to normal operation.
- **RF35** — The system must be able to create an incident for relevant unavailability.
- **RF36** — Users following a service must be able to receive incident alerts.

### Community

- **RF37** — Authenticated users must be able to comment on public services.
- **RF38** — Authenticated users must be able to report possible failures in public services.
- **RF39** — The system must expose the volume of recent community reports for a service.
- **RF40** — Community reports must not directly modify the automated technical status.
- **RF41** — The system must support comment moderation.
- **RF42** — The system must support report moderation.

### Administration

- **RF43** — Administrators must be able to add services to the Community catalog.
- **RF44** — Administrators must be able to disable or remove Community services.
- **RF45** — Administrators must be able to moderate Community content.
- **RF46** — The system must prevent inappropriate duplication in the public catalog.

## Non-functional requirements

### Technology

- **RNF01** — The application core must be developed primarily in Gleam.
- **RNF02** — The monitoring runtime must make use of the BEAM ecosystem.

### Concurrency and fault isolation

- **RNF03** — Checking one service must not block checks for unrelated services.
- **RNF04** — Failure in one monitor must not terminate other monitoring processes.

### Reliability

- **RNF05** — Network errors must be handled without unexpected application termination.
- **RNF06** — Check results must be persisted consistently.
- **RNF07** — Temporary internal failures should not cause complete loss of monitoring history.

### Security and privacy

- **RNF08** — Private endpoints must only be accessible by authorized users.
- **RNF09** — Credentials, tokens, and secrets must not be stored directly in source code.
- **RNF10** — Private monitoring data must not leak through public logs or public views.
- **RNF11** — Administrative operations must require appropriate authorization.

### Performance and scalability

- **RNF12** — The monitoring engine must support concurrent execution of multiple checks.
- **RNF13** — Increasing the number of services must not require all checks to execute sequentially.

### Maintainability and quality

- **RNF14** — Domain rules must be separated from infrastructure concerns where practical.
- **RNF15** — Core business rules must have automated tests.
- **RNF16** — Source code must follow Gleam ecosystem formatting and conventions.
- **RNF17** — Relevant architectural decisions must be documented.

### Observability

- **RNF18** — PulseBeam must log internal errors related to monitoring execution.
- **RNF19** — Internal PulseBeam failures must be distinguishable from failures of monitored services.

## Business rules

- **RN01 — UP classification:** a check is `UP` when the received HTTP status matches the configured expected status.
- **RN02 — Unexpected status:** a valid HTTP response with an unexpected status results in `DOWN` with the unexpected status preserved.
- **RN03 — Timeout:** a request exceeding the configured timeout results in `DOWN` with a timeout reason.
- **RN04 — Connection failure:** DNS failures, refused connections, and equivalent connection failures result in `DOWN`, preserving the reason where possible.
- **RN05 — Uptime:** availability is calculated as successful checks divided by total considered checks, multiplied by 100.
- **RN06 — Insufficient history:** a service without sufficient monitoring history must show metrics such as uptime or Health Score as unavailable rather than assuming perfect health.
- **RN07 — Community reports:** community reports are a separate source of information and must not directly override automated monitoring status.
- **RN08 — Private services:** private services are restricted to their owner or explicitly authorized users in future versions.
- **RN09 — Community catalog:** public Community services require administrative approval to reduce spam, incorrect URLs, and duplicates.
- **RN10 — Health Score:** Health Score must be expressed from 0 to 100 and calculated from documented objective monitoring data. The exact formula is intentionally deferred until the metrics model is designed.

## Future consideration

The initial status model uses `UP` and `DOWN`. A future model may introduce states such as `DEGRADED` or `UNKNOWN` when the product has enough data and rules to distinguish these states consistently.
