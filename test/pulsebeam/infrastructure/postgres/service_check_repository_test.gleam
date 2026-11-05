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
// Helpers
// -----------------------------------------------------------------------------

fn with_rollback(run: fn(pog.Connection) -> Nil) -> Nil {
  let database = test_postgres.database()

  let assert Error(pog.TransactionRolledBack("rollback-for-test")) =
    pog.transaction(database, fn(transaction) {
      run(transaction)
      Error("rollback-for-test")
    })

  Nil
}

fn insert_service(database: pog.Connection, name: String) -> service.Service {
  let assert Ok(monitored_service) =
    service.new(name, "https://example.com", 200, 60, service.Private)

  let assert Ok(Nil) = service_repository.insert(database, monitored_service)

  monitored_service
}

fn http_check(
  monitored_service: service.Service,
  checked_at: Int,
  http_status: Int,
  latency_ms: Int,
) -> service_check.ServiceCheck {
  let status = case http_status == service.expected_status(monitored_service) {
    True -> service_check.Up
    False -> service_check.Down
  }

  service_check.ServiceCheck(
    service_id: service.id(monitored_service),
    checked_at: timestamp.from_unix_seconds(checked_at),
    latency_ms: Some(latency_ms),
    outcome: service_check.HttpResponse(http_status),
    status: status,
  )
}

fn failure_check(
  monitored_service: service.Service,
  checked_at: Int,
  reason: service_check.ServiceCheckError,
) -> service_check.ServiceCheck {
  service_check.ServiceCheck(
    service_id: service.id(monitored_service),
    checked_at: timestamp.from_unix_seconds(checked_at),
    latency_ms: None,
    outcome: service_check.Failure(reason),
    status: service_check.Down,
  )
}

fn store_check(
  database: pog.Connection,
  check: service_check.ServiceCheck,
) -> Nil {
  let assert Ok(Nil) = service_check_repository.store(database, check)

  Nil
}

// -----------------------------------------------------------------------------
// 1. Persistence: HTTP response and timeout
// -----------------------------------------------------------------------------

pub fn store_http_and_timeout_columns_test() {
  with_rollback(fn(database) {
    let monitored_service = insert_service(database, "Store Test")

    let http = http_check(monitored_service, 1_700_000_000, 200, 42)

    let timeout =
      failure_check(monitored_service, 1_700_000_060, service_check.Timeout)

    store_check(database, http)
    store_check(database, timeout)

    // Verify the physical PostgreSQL representation of both outcomes.
    let query =
      pog.query(
        "
        SELECT (
          COUNT(*) = 2
          AND COUNT(*) FILTER (
            WHERE checked_at = $2::timestamptz
              AND status = 'up'
              AND http_status = 200
              AND latency_ms = 42
              AND error_reason IS NULL
          ) = 1
          AND COUNT(*) FILTER (
            WHERE checked_at = $3::timestamptz
              AND status = 'down'
              AND http_status IS NULL
              AND latency_ms IS NULL
              AND error_reason = 'timeout'
          ) = 1
        )
        FROM service_checks
        WHERE service_id = $1::uuid
        ",
      )
      |> pog.parameter(
        service.id(monitored_service)
        |> service.service_id_to_string
        |> pog.text,
      )
      |> pog.parameter(pog.timestamp(http.checked_at))
      |> pog.parameter(pog.timestamp(timeout.checked_at))
      |> pog.returning(decode.at([0], decode.bool))

    let assert Ok(pog.Returned(rows: [valid], ..)) =
      pog.execute(query, database)

    assert valid == True
    Nil
  })
}

// -----------------------------------------------------------------------------
// 2. Full history: newest first and domain reconstruction
// -----------------------------------------------------------------------------

pub fn for_service_returns_newest_first_test() {
  with_rollback(fn(database) {
    let monitored_service = insert_service(database, "History Test")

    let first = http_check(monitored_service, 1_700_000_000, 200, 42)
    let second =
      failure_check(monitored_service, 1_700_000_060, service_check.Timeout)

    store_check(database, first)
    store_check(database, second)

    let assert Ok([latest, earliest]) =
      service_check_repository.for_service(
        database,
        service.id(monitored_service),
      )

    assert latest == second
    assert earliest == first
    Nil
  })
}

// -----------------------------------------------------------------------------
// 3. Period queries: inclusive boundaries
// -----------------------------------------------------------------------------

pub fn between_returns_checks_within_period_test() {
  with_rollback(fn(database) {
    let monitored_service = insert_service(database, "Period Test")
    let service_id = service.id(monitored_service)

    let first = http_check(monitored_service, 1_700_000_000, 200, 20)
    let second = http_check(monitored_service, 1_700_000_060, 200, 40)
    let third =
      failure_check(monitored_service, 1_700_000_120, service_check.Timeout)

    store_check(database, first)
    store_check(database, second)
    store_check(database, third)

    let assert Ok([latest, earliest]) =
      service_check_repository.between(
        database,
        service_id,
        second.checked_at,
        third.checked_at,
      )

    assert latest == third
    assert earliest == second

    let assert Ok([]) =
      service_check_repository.between(
        database,
        service_id,
        timestamp.from_unix_seconds(1_700_000_200),
        timestamp.from_unix_seconds(1_700_000_300),
      )

    Nil
  })
}

// -----------------------------------------------------------------------------
// 4. Service isolation
// -----------------------------------------------------------------------------

pub fn history_is_isolated_by_service_test() {
  with_rollback(fn(database) {
    let first_service = insert_service(database, "First Service")
    let second_service = insert_service(database, "Second Service")

    let first = http_check(first_service, 1_700_000_000, 200, 42)
    let second =
      failure_check(second_service, 1_700_000_000, service_check.Timeout)

    store_check(database, first)
    store_check(database, second)

    let assert Ok([first_result]) =
      service_check_repository.for_service(database, service.id(first_service))

    let assert Ok([second_result]) =
      service_check_repository.for_service(database, service.id(second_service))

    assert first_result == first
    assert second_result == second

    let assert Ok([period_result]) =
      service_check_repository.between(
        database,
        service.id(first_service),
        first.checked_at,
        first.checked_at,
      )

    assert period_result == first
    Nil
  })
}

// -----------------------------------------------------------------------------
// 5. Empty history
// -----------------------------------------------------------------------------

pub fn empty_history_returns_empty_list_test() {
  with_rollback(fn(database) {
    let monitored_service = insert_service(database, "Empty History")
    let service_id = service.id(monitored_service)

    let assert Ok([]) =
      service_check_repository.for_service(database, service_id)

    let assert Ok([]) =
      service_check_repository.between(
        database,
        service_id,
        timestamp.from_unix_seconds(1_700_000_000),
        timestamp.from_unix_seconds(1_700_000_120),
      )

    Nil
  })
}

// -----------------------------------------------------------------------------
// 6. Deterministic ordering for identical timestamps
// -----------------------------------------------------------------------------

pub fn checks_with_same_timestamp_are_ordered_test() {
  with_rollback(fn(database) {
    let monitored_service = insert_service(database, "Same Timestamp")

    let first = http_check(monitored_service, 1_700_000_000, 200, 20)
    let second = http_check(monitored_service, 1_700_000_000, 503, 50)

    store_check(database, first)
    store_check(database, second)

    let service_id = service.id(monitored_service)

    let assert Ok([latest, earliest]) =
      service_check_repository.for_service(database, service_id)

    assert latest == second
    assert earliest == first

    let assert Ok([newest, oldest]) =
      service_check_repository.between(
        database,
        service_id,
        first.checked_at,
        first.checked_at,
      )

    assert newest == second
    assert oldest == first
    Nil
  })
}

// -----------------------------------------------------------------------------
// 7. Failure reasons: complete round-trip
// -----------------------------------------------------------------------------

pub fn failure_reasons_round_trip_test() {
  with_rollback(fn(database) {
    let monitored_service = insert_service(database, "Failure Reasons")

    let timeout =
      failure_check(monitored_service, 1_700_000_000, service_check.Timeout)

    let connection_failed =
      failure_check(
        monitored_service,
        1_700_000_060,
        service_check.ConnectionFailed,
      )

    let invalid_request =
      failure_check(
        monitored_service,
        1_700_000_120,
        service_check.InvalidRequest,
      )

    let invalid_response =
      failure_check(
        monitored_service,
        1_700_000_180,
        service_check.InvalidResponse,
      )

    store_check(database, timeout)
    store_check(database, connection_failed)
    store_check(database, invalid_request)
    store_check(database, invalid_response)

    let assert Ok([fourth, third, second, first]) =
      service_check_repository.for_service(
        database,
        service.id(monitored_service),
      )

    assert first == timeout
    assert second == connection_failed
    assert third == invalid_request
    assert fourth == invalid_response
    Nil
  })
}
