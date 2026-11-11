# PulseBeam

PulseBeam is an open-source project in progress, built with **Gleam** and the **BEAM ecosystem**, to monitor the availability and performance of digital services, APIs, and HTTP endpoints.

The project follows an incremental software engineering approach, with documented requirements, architecture, implementation, tests, and technical decisions.

> **Project status:** Stage 4 / v0.2 — **Persistent Monitoring (in progress)**. PulseBeam currently provides a monitoring core and PostgreSQL repository adapters; it is **not yet a continuously running monitoring platform or web application**.

## Product vision

PulseBeam is designed around one shared Monitoring Engine and two future experiences:

- **PulseBeam Community** — a public catalog where people can follow the availability and history of widely used digital services.
- **My PulseBeam** — a private area where users can monitor endpoints they own without publishing them to the community.

Both experiences are planned; they are not available as web applications yet. See the [Product Vision](docs/vision.md) and [Requirements](docs/requirements.md).

## What is implemented

### Monitoring core (v0.1 — completed)

- Service creation, validation, stable identity, visibility (Community/Private), and enabled state.
- HTTP checks recording the response status, check timestamp, and measured latency.
- UP/DOWN classification based on each service's expected HTTP status.
- Explicit outcomes for timeouts, connection failures, and invalid requests/responses.
- In-memory check history, including service and time-range queries.
- Uptime calculations for defined periods.

### PostgreSQL persistence (v0.2 — partially completed)

- PostgreSQL adapters through [`pog`](https://hexdocs.pm/pog/).
- `ServiceRepository`: insert, update, lookup by ID, and list persisted services.
- `ServiceCheckRepository`: store observations, fetch history by service, and query inclusive time ranges.
- Preservation of service identity, timestamps, UP/DOWN status, HTTP responses, latency, and failure reasons when reconstructing domain values.
- Newest-first history ordering, with deterministic tie-breaking for identical timestamps.
- SQL migrations for `services` and `service_checks`, including constraints and a history index.
- Domain and PostgreSQL integration tests, with transaction rollbacks for database isolation.

The persistence layer is implemented, but application-level runtime wiring and automatic recovery after a restart are **not yet complete**.

### Replaceable HTTP and clock infrastructure (v0.2 — implemented in #18)

- `HttpTransport` and `Clock` ports decouple monitoring execution from concrete network and time APIs.
- `monitoring/checker.run()` coordinates checks with injected dependencies; `monitoring/live.run()` composes the real adapters.
- `service_check.from_result()` handles HTTP outcomes and UP/DOWN classification without accessing the network or system clock.
- The real HTTP adapter uses `gleam/httpc` and translates errors into domain error variants.
- `checked_at` uses calendar time; elapsed request latency uses a monotonic BEAM clock.
- Unit tests use fake ports, while real HTTP integration tests use a local loopback test server rather than public internet services.

## What's next

The remaining v0.2 work includes:

- Scheduling checks automatically and running independent monitors under BEAM supervision.
- Composing the new monitoring adapters into the persistent, supervised runtime.
- Connecting the monitoring runtime to the persisted repositories and recovering state after restarts.
- Improving connection-pool lifecycle management and automated integration-test setup.

A public web UI, private user accounts, dashboards, alerts, and community interactions belong to later milestones.

## Technology

| Layer | Technology |
| --- | --- |
| Language / runtime | Gleam / Erlang OTP (BEAM) |
| HTTP checks | `gleam_http`, `gleam_httpc`, replaceable transport port |
| Database | PostgreSQL 17 |
| Database client | `pog` |
| Tests | `gleeunit` and PostgreSQL integration tests |
| Development environment | GitHub Codespaces / Docker |

## Getting started

### Docker development environment

With Docker Desktop running, start the Gleam/Erlang development container and
PostgreSQL from the repository root (works in PowerShell and Unix shells):

```sh
docker compose up -d --build --wait
docker compose exec dev gleam test
docker compose exec dev sh
```

The source directory is mounted into `/workspace`, so local edits are immediately
available inside the container. The first startup creates and migrates both
`pulsebeam` and `pulsebeam_test`; tests use the dedicated test database automatically.
See [Local Development](docs/development.md#docker-development-environment-recommended)
for common commands and database lifecycle details.

### Requirements

- Gleam 1.19 or newer
- Erlang/OTP 28
- Compatible Rebar3
- Docker

From the repository root:

```bash
gleam deps download
```

Start a **local development-only** PostgreSQL instance:

```bash
docker run -d \
  --name pulsebeam-postgres \
  -e POSTGRES_USER=pulsebeam \
  -e POSTGRES_PASSWORD=pulsebeam \
  -e POSTGRES_DB=pulsebeam \
  -p 127.0.0.1:5432:5432 \
  -v pulsebeam_pgdata:/var/lib/postgresql/data \
  postgres:17-alpine
```

If you already created this container, use `docker start pulsebeam-postgres` instead. The following setup commands are intended for **new databases**; the SQL migrations are not designed for repeated application.

Create the dedicated integration-test database:

```bash
docker exec pulsebeam-postgres \
  createdb -U pulsebeam -O pulsebeam pulsebeam_test
```

Apply both migrations in order to the development database:

```bash
for migration in db/migrations/*.sql; do
  docker exec -i pulsebeam-postgres \
    psql -v ON_ERROR_STOP=1 -U pulsebeam -d pulsebeam < "$migration" || exit 1
done
```

And to the test database:

```bash
for migration in db/migrations/*.sql; do
  docker exec -i pulsebeam-postgres \
    psql -v ON_ERROR_STOP=1 -U pulsebeam -d pulsebeam_test < "$migration" || exit 1
done
```

Run the test suite against the dedicated test database:

```bash
export PULSEBEAM_DATABASE_URL="postgresql://pulsebeam:pulsebeam@127.0.0.1:5432/pulsebeam_test?sslmode=disable"

gleam format --check
gleam test
```

**Important:** the sample credentials are for local development only. Do not use them in production, and do not point integration tests at a development or production database.

For setup details, troubleshooting, and current limitations, see [Local Development](docs/development.md).

## Architecture

PulseBeam keeps persistence contracts separate from the PostgreSQL implementation:

```text
src/pulsebeam/
├── service.gleam
├── service_check.gleam
├── check_history.gleam
├── uptime.gleam
├── monitoring/
│   ├── ports.gleam
│   ├── checker.gleam
│   └── live.gleam
├── repository/
│   ├── persistence_error.gleam
│   ├── service_repository.gleam
│   └── service_check_repository.gleam
└── infrastructure/
    ├── clock/
    │   └── system.gleam
    ├── http/
    │   └── transport.gleam
    └── postgres/
        ├── connection.gleam
        ├── service_repository.gleam
        └── service_check_repository.gleam
```

Domain types do not depend on PostgreSQL or SQL. The PostgreSQL adapters translate between database rows and domain values and map storage failures into PulseBeam persistence errors.

HTTP transport and clock access are now implemented in infrastructure adapters. The monitoring domain stays independent of both. Automatic scheduling, BEAM supervision, and restart recovery are not yet implemented.

For design details, see [Architecture](docs/architecture.md), [Persistence Architecture](docs/persistence.md), and [ADR-0003](docs/adr/0003-postgresql-persistence.md).

## Roadmap

| Milestone | Focus | Status |
| --- | --- | --- |
| v0.1 | Monitoring core: checks, in-memory history, uptime | Completed |
| v0.2 | Persistent monitoring, scheduling, BEAM concurrency | In progress |
| v0.3 | Metrics and average latency | Planned |
| v0.4 | Health Score | Planned |
| v0.5 | Web platform and API | Planned |
| v0.6 | My PulseBeam | Planned |
| v0.7 | Community | Planned |
| v0.8 | Favorites and alerts | Planned |
| v0.9 | Reports, comments, and moderation | Planned |
| v1.0 | Collaborative monitoring platform | Planned |

See the [Product Backlog](docs/backlog.md) for the detailed scope and acceptance criteria.

## Documentation

- [Product Vision](docs/vision.md)
- [Requirements](docs/requirements.md)
- [Product Backlog](docs/backlog.md)
- [Architecture](docs/architecture.md)
- [Domain Model](docs/domain.md)
- [Persistence Architecture](docs/persistence.md)
- [Local Development](docs/development.md)

## License

A license has not been selected yet.
