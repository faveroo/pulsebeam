import gleam/list
import gleam/option.{None, Some}
import pog
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/repository/persistence_error
import pulsebeam/service
import support/postgres as test_postgres

// -----------------------------------------------------------------------------
// Insert
// -----------------------------------------------------------------------------

pub fn insert_service_test() {
  let database = test_postgres.database()

  let assert Ok(original) =
    service.new(
      "PulseBeam Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) = service_repository.insert(transaction, original)

      let assert Ok(Some(loaded)) =
        service_repository.find_by_id(transaction, service.id(original))

      assert service.id(loaded) == service.id(original)

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(original))
}

// -----------------------------------------------------------------------------
// Duplicate ID
// -----------------------------------------------------------------------------

pub fn duplicate_service_id_returns_conflict_test() {
  let database = test_postgres.database()

  let assert Ok(original) =
    service.new(
      "Duplicate Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) = service_repository.insert(transaction, original)

      let second = service_repository.insert(transaction, original)

      assert second == Error(persistence_error.Conflict)

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(original))
}

// -----------------------------------------------------------------------------
// Round-trip
// -----------------------------------------------------------------------------

pub fn service_round_trip_test() {
  let database = test_postgres.database()

  let assert Ok(original) =
    service.new(
      "Round Trip Service",
      "https://round-trip.example.com",
      204,
      120,
      service.Community,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) = service_repository.insert(transaction, original)

      let assert Ok(Some(loaded)) =
        service_repository.find_by_id(transaction, service.id(original))

      assert service.id(loaded) == service.id(original)
      assert service.name(loaded) == service.name(original)
      assert service.url(loaded) == service.url(original)

      assert service.expected_status(loaded)
        == service.expected_status(original)

      assert service.interval_seconds(loaded)
        == service.interval_seconds(original)

      assert service.is_enabled(loaded) == service.is_enabled(original)

      assert service.visibility(loaded) == service.visibility(original)

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(original))
}

// -----------------------------------------------------------------------------
// Enabled state
// -----------------------------------------------------------------------------

pub fn disabled_state_is_persisted_test() {
  let database = test_postgres.database()

  let assert Ok(original) =
    service.new(
      "Disable Test",
      "https://disable.example.com",
      200,
      60,
      service.Private,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) = service_repository.insert(transaction, original)

      let disabled = service.disable(original)

      let assert Ok(Nil) = service_repository.update(transaction, disabled)

      let assert Ok(Some(loaded)) =
        service_repository.find_by_id(transaction, service.id(original))

      assert service.is_enabled(loaded) == False
      assert service.id(loaded) == service.id(original)

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(original))
}

// -----------------------------------------------------------------------------
// List
// -----------------------------------------------------------------------------

pub fn list_services_test() {
  let database = test_postgres.database()

  let assert Ok(original) =
    service.new(
      "List Test Service",
      "https://list.example.com",
      200,
      60,
      service.Community,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) = service_repository.insert(transaction, original)

      let assert Ok(services) = service_repository.list(transaction)

      assert list.any(services, fn(loaded) {
        service.id(loaded) == service.id(original)
        && service.name(loaded) == service.name(original)
      })

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(original))
}

// -----------------------------------------------------------------------------
// Update nonexistent service
// -----------------------------------------------------------------------------

pub fn update_nonexistent_service_returns_not_found_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new(
      "Nonexistent Service",
      "https://nonexistent.example.com",
      200,
      60,
      service.Private,
    )

  let result = service_repository.update(database, monitored_service)

  assert result == Error(persistence_error.NotFound)
}
