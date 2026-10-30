import envoy
import gleam/erlang/process
import gleam/option.{Some}
import pulsebeam/infrastructure/postgres/connection
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/repository/persistence_error
import pulsebeam/service

pub fn insert_service_test() {
  let assert Ok(database_url) = envoy.get("PULSEBEAM_DATABASE_URL")

  let pool_name = process.new_name("pulsebeam_service_repository_test")

  let assert Ok(database) = connection.start(pool_name, database_url)

  process.sleep(500)

  let assert Ok(monitored_service) =
    service.new(
      "PulseBeam Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let result = service_repository.insert(database, monitored_service)

  assert result == Ok(Nil)
}

pub fn duplicate_service_id_returns_conflict_test() {
  let assert Ok(database_url) = envoy.get("PULSEBEAM_DATABASE_URL")

  let pool_name = process.new_name("pulsebeam_duplicate_service_test")

  let assert Ok(database) = connection.start(pool_name, database_url)

  process.sleep(500)

  let assert Ok(monitored_service) =
    service.new(
      "Duplicate Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let first = service_repository.insert(database, monitored_service)

  let second = service_repository.insert(database, monitored_service)

  assert first == Ok(Nil)
  assert second == Error(persistence_error.Conflict)
}

pub fn service_round_trip_test() {
  let assert Ok(database_url) = envoy.get("PULSEBEAM_DATABASE_URL")

  let pool_name = process.new_name("pulsebeam_service_round_trip_test")

  let assert Ok(database) = connection.start(pool_name, database_url)

  process.sleep(500)

  let assert Ok(original) =
    service.new(
      "Round Trip Service",
      "https://round-trip.example.com",
      204,
      120,
      service.Community,
    )

  let assert Ok(Nil) = service_repository.insert(database, original)

  let assert Ok(Some(loaded)) =
    service_repository.find_by_id(database, service.id(original))

  assert service.service_id_to_string(service.id(loaded))
    == service.service_id_to_string(service.id(original))

  assert service.name(loaded) == service.name(original)
  assert service.url(loaded) == service.url(original)
  assert service.expected_status(loaded) == service.expected_status(original)
  assert service.interval_seconds(loaded) == service.interval_seconds(original)
  assert service.is_enabled(loaded) == service.is_enabled(original)
  assert service.visibility(loaded) == service.visibility(original)
}

pub fn disabled_state_is_persisted_test() {
  let assert Ok(database_url) = envoy.get("PULSEBEAM_DATABASE_URL")

  let pool_name = process.new_name("pulsebeam_disabled_state_test")

  let assert Ok(database) = connection.start(pool_name, database_url)

  process.sleep(500)

  let assert Ok(original) =
    service.new(
      "Disable Test",
      "https://disable.example.com",
      200,
      60,
      service.Private,
    )

  let assert Ok(Nil) = service_repository.insert(database, original)

  let disabled = service.disable(original)

  let assert Ok(Nil) = service_repository.update(database, disabled)

  let assert Ok(Some(loaded)) =
    service_repository.find_by_id(database, service.id(original))

  assert service.is_enabled(loaded) == False

  assert service.service_id_to_string(service.id(loaded))
    == service.service_id_to_string(service.id(original))
}
