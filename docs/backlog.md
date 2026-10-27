# Product Backlog

This backlog records the initial epics, user stories, acceptance criteria, and delivery order for PulseBeam.

## EPIC 01 — Monitoring Core

### US01 — Register service

**As a** user, **I want** to register a service or endpoint for monitoring, **so that** PulseBeam can track its availability.

Acceptance criteria:
- Name is required.
- URL is required.
- Expected HTTP status can be configured.
- Check interval can be configured.
- A new service starts enabled by default.
- Invalid input is rejected.

Related: RF01, RF02.

### US02 — Execute HTTP check

**As a** user, **I want** PulseBeam to check the service periodically, **so that** I know whether it is available.

Acceptance criteria:
- An HTTP request is executed.
- Returned HTTP status is recorded.
- Check time is recorded.
- Communication errors are handled.
- Failure of one service does not terminate the application.

Related: RF03, RF04, RF07, RF08.

### US03 — Measure latency

**As a** user, **I want** to see service response time, **so that** I can identify performance degradation.

Acceptance criteria:
- Request duration is measured.
- Result is stored in milliseconds.
- Missing latency is distinguishable from zero latency.

Related: RF05.

### US04 — Classify status

**As a** user, **I want** PulseBeam to classify a check as UP or DOWN, **so that** I do not need to interpret raw responses manually.

Acceptance criteria:
- Expected status received -> `UP`.
- Unexpected HTTP status -> `DOWN`.
- Timeout -> `DOWN`.
- DNS or connection error -> `DOWN`.
- Failure reason is preserved.

Related: RF06, RF08, RN01-RN04.

### US05 — Disable monitoring

**As a** service owner, **I want** to disable monitoring without deleting history, **so that** I can pause checks safely.

Acceptance criteria:
- Service can be disabled.
- Disabled services are not checked.
- Previous history remains available.

Related: RF09.

## EPIC 02 — Scheduler & Concurrency

### US06 — Monitor multiple services

**As a** user, **I want** multiple services monitored at the same time, **so that** PulseBeam can centralize monitoring.

Acceptance criteria:
- Multiple services can be active.
- One check does not block unrelated checks.
- Failure in one monitor does not terminate others.

Related: RF10, RNF03, RNF04.

### US07 — Schedule automatic checks

**As a** user, **I want** checks to run automatically, **so that** manual execution is unnecessary.

Acceptance criteria:
- Each service has a monitoring interval.
- Scheduler respects the interval.
- Disabled services are not scheduled.
- Slow checks do not prevent unrelated services from being checked.

## EPIC 03 — History & Metrics

### US08 — Store check history

Each check must preserve service, timestamp, status, HTTP status when available, latency when available, and error reason when present.

Related: RF11.

### US09 — Query history

Users must be able to retrieve the chronological history of a service and constrain the queried period.

Related: RF12.

### US10 — Calculate uptime

Availability must be calculated from recorded checks for periods such as 24h, 7d, and 30d. Insufficient data must produce `N/A`, not an assumed 100%.

Related: RF13, RF15, RN05, RN06.

### US11 — Calculate average latency

Users must be able to view average valid latency for defined periods.

Related: RF14, RF15.

## EPIC 04 — Health Score

### US12 — Calculate Health Score

Health Score must range from 0 to 100, use documented objective metrics, and return `N/A` when there is insufficient data. Community reports must not directly modify the score.

Related: RF17, RN10.

### US13 — Health Score history

Historical score values must be persistable or reproducible and usable by charts.

Related: RF18.

## EPIC 05 — My PulseBeam

### US14 — Create private endpoint

Authenticated users can create private endpoints that are not visible in public searches, rankings, or Community pages.

Related: RF19, RF20, RF23, RF24, RN08.

### US15 — Manage My PulseBeam

Authenticated users have a private area containing their services, current status, metrics, history, and editable monitoring settings.

Related: RF27-RF29.

## EPIC 06 — PulseBeam Community

### US16 — View public service

Visitors can access public service status, uptime, latency, history, Health Score, incidents, and Community information without authentication.

Related: RF21, RF22.

### US17 — Manage Community catalog

Authorized administrators can add validated public services while preventing inappropriate duplicates.

Related: RF43, RF46, RN09.

## EPIC 07 — Favorites & Alerts

### US18 — Favorite public service

Authenticated users can add/remove public services from favorites and view their followed services.

Related: RF30-RF32.

### US19 — Receive incident alert

PulseBeam detects transitions into and out of failure states, creates relevant incidents, and can notify interested users.

Related: RF33-RF36.

## EPIC 08 — Community Interaction

### US20 — Report possible failure

Authenticated users can report possible problems in public services. Reports include user, service, and timestamp and do not directly override automated status.

Related: RF38-RF40, RN07.

### US21 — Comment on public service

Authenticated users can comment on public services. Comments preserve author and time and can be moderated.

Related: RF37, RF41.

## EPIC 09 — Administration & Moderation

### US22 — Moderate Community content

Authorized administrators can moderate comments and reports.

Related: RF41, RF42, RF45.

# Delivery roadmap

## v0.1 — Monitoring Core
- US01 Register service
- US02 Execute HTTP check
- US03 Measure latency
- US04 Classify status
- US08 Store check history
- US09 Query history
- US10 Calculate uptime

## v0.2 — Scheduler & BEAM
- US05 Disable monitoring
- US06 Monitor multiple services
- US07 Schedule automatic checks

## v0.3 — Metrics
- US11 Calculate average latency

## v0.4 — Health Score
- US12 Calculate Health Score
- US13 Health Score history

## v0.5 — Web Platform
Expose existing monitoring capabilities through a web/API layer and historical charts.

## v0.6 — My PulseBeam
Authentication, private endpoints, and private management area.

## v0.7 — Community
Public service catalog and Community service pages.

## v0.8 — Favorites & Alerts
Favorite public services and incident notifications.

## v0.9 — Social
Reports, comments, and moderation.

## v1.0 — Collaborative Monitoring Platform
Consolidate Monitoring Engine, My PulseBeam, Community, metrics, alerts, and Community interaction into the first complete product release.
