# Stage 3 Review — Monitoring Core

> Status: completed on 2026-10-30.

Stage 3 delivered the first executable monitoring core for PulseBeam. The implementation now covers service registration, HTTP checks, latency capture, UP/DOWN classification, in-memory check history, history queries, and uptime calculations for 24h, 7d, and 30d periods.

## Implemented modules

### `service.gleam`

Responsibilities:
- defines `Service`, `ServiceId`, `Visibility`, and validation errors;
- generates UUID v7 identifiers for new services;
- validates name, URL prefix, expected HTTP status, and monitoring interval;
- exposes immutable enable/disable operations.

Review notes:
- responsibility is cohesive for the current domain model;
- `ServiceId` is opaque, which prevents accidental mixing with arbitrary strings;
- Stage 4 must introduce a safe reconstitution path for persisted services because `new()` always generates a new identifier.

### `service_check.gleam`

Responsibilities:
- executes an HTTP check;
- records the check timestamp;
- measures response latency;
- preserves HTTP response status or transport failure reason;
- classifies the check as `Up` or `Down`.

Review notes:
- check outcome and final status are correctly kept as separate concepts;
- transport failures are mapped into domain-specific failure reasons;
- this module currently mixes domain classification with HTTP-client and clock infrastructure. Stage 4 should introduce replaceable boundaries so domain rules remain testable without real network calls;
- latency currently uses wall-clock timestamps rather than a monotonic timer.

### `check_history.gleam`

Responsibilities:
- stores checks immutably in memory;
- keeps newest checks first;
- returns the latest check;
- filters history by service;
- filters history by inclusive time period.

Review notes:
- current API is sufficient for the Stage 3 in-memory model;
- storage is process-local and is lost on restart;
- Stage 4 should replace or wrap the in-memory representation behind a repository/persistence boundary rather than coupling application logic directly to lists.

### `uptime.gleam`

Responsibilities:
- calculates uptime from UP checks divided by considered checks;
- represents unavailable metrics explicitly with `NotAvailable`;
- calculates uptime for 24h, 7d, and 30d windows;
- refuses to report a period when history does not reach the beginning of that window.

Review notes:
- mathematical calculation is separated from period-selection rules;
- callers must provide checks for the intended service; the current API does not itself enforce a single `ServiceId`;
- the current definition of "enough history" assumes that the existence of a check at or before the period boundary is sufficient evidence of coverage. A future retention/gap policy may refine this rule.

## Stage 3 completed capabilities

- Service creation and validation
- UUID v7 `ServiceId`
- Enable/disable domain state
- HTTP request execution
- HTTP status preservation
- Check timestamp
- Latency in milliseconds
- `Up` / `Down` classification
- Timeout/connection/invalid-response failure preservation
- In-memory check history
- Query by service
- Query by time period
- Uptime calculation
- 24h / 7d / 30d uptime windows
- Insufficient-history handling
- 66 passing tests at Stage 3 completion

## Technical debt carried into Stage 4

1. **Persistence is not durable.** Services and checks currently exist only in memory/domain values and are lost on restart.
2. **`ServiceId` cannot yet be reconstituted from persisted data.** A persistence-safe constructor/parser is required without allowing arbitrary invalid IDs throughout the domain.
3. **`service_check.gleam` mixes domain and infrastructure.** HTTP transport and clock/timing should become replaceable dependencies or adapters.
4. **Latency uses wall-clock time.** Duration measurement should use a monotonic clock while `checked_at` continues to use wall-clock/system time.
5. **No scheduler/runtime loop exists.** Checks are still triggered manually by callers.
6. **No concurrent monitoring runtime exists.** Multiple services are not yet supervised as independent BEAM workloads.
7. **Disabled services are represented in the domain but not yet enforced by a scheduler.**
8. **No restart recovery exists.** Enabled services and future scheduling state are not restored after process/application restart.
9. **Private-history authorization remains deferred.** History functions operate on domain data only; authorization belongs above the monitoring core when authenticated private services are introduced.
10. **Uptime assumes callers pass one service's checks.** The persistence/application layer should ensure metrics are scoped to a single service before calculation.

## Stage 4 direction

Stage 4 is named **Persistent Monitoring**. Its purpose is to move from a pure/in-memory monitoring core to a durable runtime that can restore services, schedule checks automatically, run multiple monitors independently, and preserve checks across restarts.

The implementation should keep the Stage 3 domain rules intact while introducing explicit persistence and runtime boundaries.