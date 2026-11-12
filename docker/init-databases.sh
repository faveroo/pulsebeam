#!/bin/sh
set -eu

createdb --username "$POSTGRES_USER" --owner "$POSTGRES_USER" pulsebeam_test

for database in "$POSTGRES_DB" pulsebeam_test; do
  for migration in /migrations/*.sql; do
    psql --username "$POSTGRES_USER" --dbname "$database" \
      --set ON_ERROR_STOP=1 --file "$migration"
  done
done
