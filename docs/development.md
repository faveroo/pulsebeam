
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

Apply the initial services migration:

```bash
docker exec -i pulsebeam-postgres \
  psql -U pulsebeam -d pulsebeam \
  < db/migrations/0001_create_services.sql
```

This migration creates the `services` table with its primary key and domain constraints.

Migrations are currently applied manually. An automated migration runner has not been implemented.

## Test Database

Integration tests must use a separate PostgreSQL database.

Create it once:

```bash
docker exec pulsebeam-postgres \
  createdb -U pulsebeam -O pulsebeam pulsebeam_test
```

Apply the schema:

```bash
docker exec -i pulsebeam-postgres \
  psql -U pulsebeam -d pulsebeam_test \
  < db/migrations/0001_create_services.sql
```

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

Integration tests use transactions and explicit rollbacks to avoid leaving test records behind.

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
│   └── service_repository.gleam
└── infrastructure/
    └── postgres/
        ├── connection.gleam
        └── service_repository.gleam
```

The repository contract defines the operations expected by the application.

The PostgreSQL adapter implements these operations using `pog`, without exposing database-specific types to the domain.

## Current Limitations

- Database migrations are applied manually.
- The complete test suite currently requires PostgreSQL.
- Test database setup is not yet automated.
- Persistent ServiceCheck history and monitoring scheduling are part of subsequent development stages.
