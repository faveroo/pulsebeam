
# Local Development

This guide explains how to configure a local development environment for PulseBeam, including PostgreSQL and integration tests.

For persistence architecture decisions, see [Persistence Architecture](./persistence.md).

## Docker development environment (recommended)

Only Docker with Compose is required on the host. On Windows, start Docker Desktop
using Linux containers, then run these commands from the repository root:

```sh
docker compose up -d --build --wait
docker compose exec dev gleam --version
docker compose exec dev gleam format --check
docker compose exec dev gleam test
```

The development image uses Gleam 1.19.2, Erlang/OTP 28, Rebar3, Git, and native
build tools. It follows the [official Gleam Docker deployment approach](https://gleam.run/deployment/linux-server/)
of copying the compiler from the published Gleam image. PostgreSQL 17 runs in a
separate service. The development container stays running so commands are available
without rebuilding the image each time:

```sh
docker compose exec dev sh
docker compose exec dev gleam run
docker compose exec dev gleam deps download
docker compose logs postgres
docker compose stop
docker compose start
```

`gleam run` currently prints the placeholder greeting from `src/pulsebeam.gleam`;
there is no web server to expose yet.

The repository is mounted at `/workspace`. Edit files with your normal host editor;
the container sees those changes immediately. A named volume keeps Linux build
artifacts separate from the host's `build/` directory. After changing dependencies,
run `docker compose exec dev gleam deps download`. After changing the Dockerfile,
run `docker compose up -d --build --wait` again.

`.gitattributes` keeps Gleam sources and Docker shell scripts in LF format on
Windows too, so the Linux formatter and initialization scripts work consistently.

On the first startup with an empty database volume, `docker/init-databases.sh`
creates `pulsebeam_test` and applies every SQL file in `db/migrations/`, in filename
order, to both databases:

| Database | Purpose | URL inside the development container |
| --- | --- | --- |
| `pulsebeam` | Development data | `postgresql://pulsebeam:pulsebeam@postgres:5432/pulsebeam?sslmode=disable` |
| `pulsebeam_test` | Integration tests | `postgresql://pulsebeam:pulsebeam@postgres:5432/pulsebeam_test?sslmode=disable` |

`PULSEBEAM_DATABASE_URL` defaults to the test database inside `dev`, because the
current test helper reads that variable. The example credentials are for local
development only. From the host, use `127.0.0.1` instead of `postgres`. PostgreSQL is
published only on localhost. If port 5432 is busy, set `PULSEBEAM_POSTGRES_PORT=5433`
in a local `.env` file before starting Compose; the internal URLs stay the same.

Database data survives `docker compose stop` and `docker compose down`. The init
script does not run again for an existing volume. New migrations must be applied
once to each database; for example:

```sh
docker compose exec postgres psql -U pulsebeam -d pulsebeam -v ON_ERROR_STOP=1 -f /migrations/0003_example.sql
docker compose exec postgres psql -U pulsebeam -d pulsebeam_test -v ON_ERROR_STOP=1 -f /migrations/0003_example.sql
```

Replace the example filename with the new migration. Do not reapply existing
`CREATE TABLE` migrations. To deliberately erase both databases and the container
build cache, use `docker compose down -v`, then start again with
`docker compose up -d --build --wait`.

The following sections describe the alternative setup with Gleam running on the host.

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

- After initial Compose setup, new database migrations are applied manually.
- The complete test suite currently requires PostgreSQL.
- Test database setup is automated for fresh Compose volumes; host setup is manual.
- Persistent ServiceCheck history is implemented; automated monitoring scheduling and restart recovery remain future work.
- Pool lifecycle management, standalone domain-test execution, and automated CI integration-test setup remain technical debt.
