import gleam/dynamic/decode
import gleam/option.{None, Some}
import gleam/time/timestamp
import pog
import pulsebeam/infrastructure/postgres/service_check_repository
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/service
import pulsebeam/service_check
import support/postgres as test_postgres

// -----------------------------------------------------------------------------
// Store HTTP response
// -----------------------------------------------------------------------------

pub fn store_http_response_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new(
      "HTTP Response Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let check =
    service_check.ServiceCheck(
      service_id: service.id(monitored_service),
      checked_at: checked_at,
      latency_ms: Some(42),
      outcome: service_check.HttpResponse(200),
      status: service_check.Up,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) =
        service_repository.insert(transaction, monitored_service)

      let assert Ok(Nil) = service_check_repository.store(transaction, check)

      let query =
        pog.query(
          "
          SELECT
            status = 'up'
            AND http_status = 200
            AND latency_ms = 42
            AND error_reason IS NULL
            AND checked_at = $2::timestamptz
          FROM service_checks
          WHERE service_id = $1::uuid
          LIMIT 1
          ",
        )
        |> pog.parameter(
          service.id(monitored_service)
          |> service.service_id_to_string
          |> pog.text,
        )
        |> pog.parameter(pog.timestamp(checked_at))
        |> pog.returning(decode.at([0], decode.bool))

      let assert Ok(pog.Returned(rows: [matches], ..)) =
        pog.execute(query, transaction)

      assert matches == True

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(monitored_service))
}

// -----------------------------------------------------------------------------
// Store timeout failure
// -----------------------------------------------------------------------------

pub fn store_timeout_failure_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new("Timeout Test", "https://example.com", 200, 60, service.Private)

  let checked_at = timestamp.from_unix_seconds(1_700_000_001)

  let check =
    service_check.ServiceCheck(
      service_id: service.id(monitored_service),
      checked_at: checked_at,
      latency_ms: None,
      outcome: service_check.Failure(service_check.Timeout),
      status: service_check.Down,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) =
        service_repository.insert(transaction, monitored_service)

      let assert Ok(Nil) = service_check_repository.store(transaction, check)

      let query =
        pog.query(
          "
          SELECT
            status = 'down'
            AND http_status IS NULL
            AND latency_ms IS NULL
            AND error_reason = 'timeout'
            AND checked_at = $2::timestamptz
          FROM service_checks
          WHERE service_id = $1::uuid
          LIMIT 1
          ",
        )
        |> pog.parameter(
          service.id(monitored_service)
          |> service.service_id_to_string
          |> pog.text,
        )
        |> pog.parameter(pog.timestamp(checked_at))
        |> pog.returning(decode.at([0], decode.bool))

      let assert Ok(pog.Returned(rows: [matches], ..)) =
        pog.execute(query, transaction)

      assert matches == True

      Error("rollback-for-test")
    })

  let assert Ok(None) =
    service_repository.find_by_id(database, service.id(monitored_service))
}

pub fn for_service_returns_newest_first_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new("History Test", "https://example.com", 200, 60, service.Private)

  let service_id = service.id(monitored_service)

  let first =
    service_check.ServiceCheck(
      service_id: service_id,
      checked_at: timestamp.from_unix_seconds(1_700_000_000),
      latency_ms: Some(42),
      outcome: service_check.HttpResponse(200),
      status: service_check.Up,
    )

  let second =
    service_check.ServiceCheck(
      service_id: service_id,
      checked_at: timestamp.from_unix_seconds(1_700_000_060),
      latency_ms: None,
      outcome: service_check.Failure(service_check.Timeout),
      status: service_check.Down,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) =
        service_repository.insert(transaction, monitored_service)

      let assert Ok(Nil) = service_check_repository.store(transaction, first)

      let assert Ok(Nil) = service_check_repository.store(transaction, second)

      let assert Ok([latest, earliest]) =
        service_check_repository.for_service(transaction, service_id)

      assert latest.outcome == service_check.Failure(service_check.Timeout)

      assert latest.status == service_check.Down
      assert latest.latency_ms == None

      assert earliest.outcome == service_check.HttpResponse(200)
      assert earliest.status == service_check.Up
      assert earliest.latency_ms == Some(42)

      assert latest.checked_at == second.checked_at
      assert earliest.checked_at == first.checked_at

      assert latest.service_id == service_id
      assert earliest.service_id == service_id

      Error("rollback-for-test")
    })
}

pub fn between_returns_checks_within_period_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new("Period Test", "https://example.com", 200, 60, service.Private)

  let service_id = service.id(monitored_service)

  let first_time = timestamp.from_unix_seconds(1_700_000_000)
  let middle_time = timestamp.from_unix_seconds(1_700_000_060)
  let last_time = timestamp.from_unix_seconds(1_700_000_120)

  let first =
    service_check.ServiceCheck(
      service_id: service_id,
      checked_at: first_time,
      latency_ms: Some(20),
      outcome: service_check.HttpResponse(200),
      status: service_check.Up,
    )

  let middle =
    service_check.ServiceCheck(
      service_id: service_id,
      checked_at: middle_time,
      latency_ms: Some(40),
      outcome: service_check.HttpResponse(200),
      status: service_check.Up,
    )

  let last =
    service_check.ServiceCheck(
      service_id: service_id,
      checked_at: last_time,
      latency_ms: None,
      outcome: service_check.Failure(service_check.Timeout),
      status: service_check.Down,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) =
        service_repository.insert(transaction, monitored_service)

      let assert Ok(Nil) = service_check_repository.store(transaction, first)

      let assert Ok(Nil) = service_check_repository.store(transaction, middle)

      let assert Ok(Nil) = service_check_repository.store(transaction, last)

      let assert Ok([newest, oldest]) =
        service_check_repository.between(
          transaction,
          service_id,
          middle_time,
          last_time,
        )

      assert newest.checked_at == last_time
      assert oldest.checked_at == middle_time

      assert newest.outcome == service_check.Failure(service_check.Timeout)

      assert oldest.outcome == service_check.HttpResponse(200)

      Error("rollback-for-test")
    })
}

pub fn history_is_isolated_by_service_test() {
  let database = test_postgres.database()

  let assert Ok(first_service) =
    service.new(
      "First Service",
      "https://first.example.com",
      200,
      60,
      service.Private,
    )

  let assert Ok(second_service) =
    service.new(
      "Second Service",
      "https://second.example.com",
      200,
      60,
      service.Private,
    )

  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let first_check =
    service_check.ServiceCheck(
      service_id: service.id(first_service),
      checked_at: checked_at,
      latency_ms: Some(42),
      outcome: service_check.HttpResponse(200),
      status: service_check.Up,
    )

  let second_check =
    service_check.ServiceCheck(
      service_id: service.id(second_service),
      checked_at: checked_at,
      latency_ms: None,
      outcome: service_check.Failure(service_check.Timeout),
      status: service_check.Down,
    )

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      let assert Ok(Nil) = service_repository.insert(transaction, first_service)

      let assert Ok(Nil) =
        service_repository.insert(transaction, second_service)

      let assert Ok(Nil) =
        service_check_repository.store(transaction, first_check)

      let assert Ok(Nil) =
        service_check_repository.store(transaction, second_check)

      let assert Ok([first_result]) =
        service_check_repository.for_service(
          transaction,
          service.id(first_service),
        )

      let assert Ok([second_result]) =
        service_check_repository.for_service(
          transaction,
          service.id(second_service),
        )

      assert first_result.outcome == service_check.HttpResponse(200)
      assert second_result.outcome
        == service_check.Failure(service_check.Timeout)

      assert first_result.service_id == service.id(first_service)
      assert second_result.service_id == service.id(second_service)

      Error("rollback-for-test")
    })
}
