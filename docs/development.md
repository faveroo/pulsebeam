
# Local Development

This guide explains how to configure a local development environment for PulseBeam, including PostgreSQL and integration tests.

For persistence architecture decisions, see [Persistence Architecture](./persistence.md).

## Prerequisites

- Gleam 1.19 or later
- Erlang/OTP 28
- A compatible Rebar3 installation
- Docker

Install Gleam project dependencies:

```bash
gleam deps download
```

## PostgreSQL

PulseBeam uses PostgreSQL for durable monitoring configuration. The database is accessed through the `pog` Gleam library.

### Start PostgreSQL

Create a PostgreSQL 17 container:

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

The named volume preserves database data when the container is stopped or recreated.

If the container already exists and is stopped, start it instead:

```bash
docker start pulsebeam-postgres
```

Check database readiness:

```bash
docker exec pulsebeam-postgres \
  pg_isready -U pulsebeam -d pulsebeam
```

The credentials above are intended for local development only. Do not reuse them in production.

## Database Schema

SQL migrations are stored in `db/migrations/`.

Apply both migrations in order:

```bash
docker exec -i pulsebeam-postgres \
  psql -v ON_ERROR_STOP=1 -U pulsebeam -d pulsebeam \
  < db/migrations/0001_create_services.sql

docker exec -i pulsebeam-postgres \
  psql -v ON_ERROR_STOP=1 -U pulsebeam -d pulsebeam \
  < db/migrations/0002_create_service_checks.sql
```

The first migration creates `services`; the second creates `service_checks`, its service foreign key, outcome constraints, and history index. Run each migration **once** on a fresh database; there is no migration tracking or automatic replay yet.

Migrations are currently applied manually. An automated migration runner has not been implemented.

## Test Database

Integration tests must use a separate PostgreSQL database.

Create it once:

```bash
docker exec pulsebeam-postgres \
  createdb -U pulsebeam -O pulsebeam pulsebeam_test
```

Apply the same migrations to the test database, in order:

```bash
docker exec -i pulsebeam-postgres \
  psql -v ON_ERROR_STOP=1 -U pulsebeam -d pulsebeam_test \
  < db/migrations/0001_create_services.sql

docker exec -i pulsebeam-postgres \
  psql -v ON_ERROR_STOP=1 -U pulsebeam -d pulsebeam_test \
  < db/migrations/0002_create_service_checks.sql
```

Do not reapply these `CREATE TABLE` scripts to a database in which the tables already exist.

Do not run destructive integration tests against the development or production database.

## Running Tests

The test database connection is configured through the `PULSEBEAM_DATABASE_URL` environment variable.

```bash
export PULSEBEAM_DATABASE_URL="postgresql://pulsebeam:pulsebeam@127.0.0.1:5432/pulsebeam_test?sslmode=disable"
```

Run the complete test suite:

```bash
gleam test
```

The suite currently includes both domain tests and PostgreSQL integration tests. Therefore, the test database must be available when running the complete suite.

Integration tests for services and service checks use transactions and explicit rollbacks to avoid leaving test records behind. The helper in `test/support/postgres.gleam` creates a new named pool per test, limits each pool to one connection, and waits until the connection is ready; **it does not explicitly shut down those pools**. The test runner currently requires a running PostgreSQL instance.

See [Persistence Architecture](./persistence.md#technical-debt-and-follow-up) for the outstanding pool lifecycle and CI isolation work.

## Code Formatting

Format the project:

```bash
gleam format
```

Run tests after making changes:

```bash
gleam test
```

## Persistence Structure

The persistence implementation is separated into repository contracts and infrastructure adapters.

```text
src/pulsebeam/
├── repository/
│   ├── persistence_error.gleam
│   ├── service_repository.gleam
│   └── service_check_repository.gleam
└── infrastructure/
    └── postgres/
        ├── connection.gleam
        ├── service_repository.gleam
        └── service_check_repository.gleam
```

The repository contract defines the operations expected by the application.

The PostgreSQL adapter implements these operations using `pog`, without exposing database-specific types to the domain.

## Current Limitations

- Database migrations are applied manually.
- The complete test suite currently requires PostgreSQL.
- Test database setup is not yet automated.
- Persistent ServiceCheck history is implemented; automated monitoring scheduling and restart recovery remain future work.
- Pool lifecycle management, standalone domain-test execution, and automated CI integration-test setup remain technical debt.
