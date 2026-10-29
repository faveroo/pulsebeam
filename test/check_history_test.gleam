import gleam/option
import gleam/time/timestamp
import pulsebeam/check_history
import pulsebeam/service
import pulsebeam/service_check

fn create_check(
  service_id: service.ServiceId,
  checked_at: timestamp.Timestamp,
) -> service_check.ServiceCheck {
  service_check.ServiceCheck(
    service_id: service_id,
    checked_at: checked_at,
    latency_ms: option.None,
    outcome: service_check.HttpResponse(200),
    status: service_check.Up,
  )
}

// ---------------------------------------------------------
// History creation / storage
// ---------------------------------------------------------

pub fn new_history_starts_empty_test() {
  let history = check_history.new()

  assert check_history.size(history) == 0
}

pub fn storing_one_check_increases_size_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  assert check_history.size(history) == 1
}

pub fn storing_multiple_checks_increases_size_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let first_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let second_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(200),
    )

  let third_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(300),
    )

  let history =
    check_history.new()
    |> check_history.store(first_check)
    |> check_history.store(second_check)
    |> check_history.store(third_check)

  assert check_history.size(history) == 3
}

pub fn storing_check_does_not_modify_original_history_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let original_history = check_history.new()

  let updated_history = check_history.store(original_history, check)

  assert check_history.size(original_history) == 0
  assert check_history.size(updated_history) == 1
}

// ---------------------------------------------------------
// Latest check
// ---------------------------------------------------------

pub fn latest_on_empty_history_returns_none_test() {
  let history = check_history.new()

  assert check_history.latest(history) == option.None
}

pub fn latest_returns_stored_check_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  assert check_history.latest(history) == option.Some(check)
}

pub fn latest_returns_most_recent_check_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let first_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let second_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(200),
    )

  let history =
    check_history.new()
    |> check_history.store(first_check)
    |> check_history.store(second_check)

  assert check_history.latest(history) == option.Some(second_check)
}

pub fn latest_preserves_check_data_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    service_check.ServiceCheck(
      service_id: service.id(monitored_service),
      checked_at: timestamp.from_unix_seconds(100),
      latency_ms: option.Some(123),
      outcome: service_check.HttpResponse(200),
      status: service_check.Up,
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  let assert option.Some(stored_check) = check_history.latest(history)

  assert service_check.service_id(stored_check)
    == service_check.service_id(check)

  assert service_check.checked_at(stored_check)
    == service_check.checked_at(check)

  assert service_check.latency_ms(stored_check)
    == service_check.latency_ms(check)

  assert service_check.outcome(stored_check) == service_check.outcome(check)

  assert service_check.status(stored_check) == service_check.status(check)
}

// ---------------------------------------------------------
// History by service
// ---------------------------------------------------------

pub fn for_service_on_empty_history_returns_empty_list_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let history = check_history.new()

  let checks = check_history.for_service(history, service.id(monitored_service))

  assert checks == []
}

pub fn for_service_ignores_checks_from_other_services_test() {
  let assert Ok(first_service) =
    service.new("First", "https://example.com", 200, 60, service.Community)

  let assert Ok(second_service) =
    service.new("Second", "https://github.com", 200, 60, service.Community)

  let second_check =
    create_check(service.id(second_service), timestamp.from_unix_seconds(100))

  let history =
    check_history.new()
    |> check_history.store(second_check)

  let checks = check_history.for_service(history, service.id(first_service))

  assert checks == []
}

pub fn for_service_returns_only_matching_checks_test() {
  let assert Ok(first_service) =
    service.new("First", "https://example.com", 200, 60, service.Community)

  let assert Ok(second_service) =
    service.new("Second", "https://github.com", 200, 60, service.Community)

  let first_check =
    create_check(service.id(first_service), timestamp.from_unix_seconds(100))

  let second_check =
    create_check(service.id(second_service), timestamp.from_unix_seconds(200))

  let history =
    check_history.new()
    |> check_history.store(first_check)
    |> check_history.store(second_check)

  let checks = check_history.for_service(history, service.id(first_service))

  assert checks == [first_check]
}

pub fn for_service_returns_newest_checks_first_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let first_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let second_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(200),
    )

  let history =
    check_history.new()
    |> check_history.store(first_check)
    |> check_history.store(second_check)

  let checks = check_history.for_service(history, service.id(monitored_service))

  assert checks == [second_check, first_check]
}

// ---------------------------------------------------------
// History by service and period
// ---------------------------------------------------------

pub fn for_service_between_excludes_check_before_period_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(monitored_service),
      timestamp.from_unix_seconds(150),
      timestamp.from_unix_seconds(250),
    )

  assert checks == []
}

pub fn for_service_between_returns_check_inside_period_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(200),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(monitored_service),
      timestamp.from_unix_seconds(150),
      timestamp.from_unix_seconds(250),
    )

  assert checks == [check]
}

pub fn for_service_between_excludes_check_after_period_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(300),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(monitored_service),
      timestamp.from_unix_seconds(150),
      timestamp.from_unix_seconds(250),
    )

  assert checks == []
}

pub fn for_service_between_includes_check_at_start_boundary_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(150),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(monitored_service),
      timestamp.from_unix_seconds(150),
      timestamp.from_unix_seconds(250),
    )

  assert checks == [check]
}

pub fn for_service_between_includes_check_at_end_boundary_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(250),
    )

  let history =
    check_history.new()
    |> check_history.store(check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(monitored_service),
      timestamp.from_unix_seconds(150),
      timestamp.from_unix_seconds(250),
    )

  assert checks == [check]
}

pub fn for_service_between_ignores_other_services_test() {
  let assert Ok(first_service) =
    service.new("First", "https://example.com", 200, 60, service.Community)

  let assert Ok(second_service) =
    service.new("Second", "https://github.com", 200, 60, service.Community)

  let first_check =
    create_check(service.id(first_service), timestamp.from_unix_seconds(200))

  let second_check =
    create_check(service.id(second_service), timestamp.from_unix_seconds(200))

  let history =
    check_history.new()
    |> check_history.store(first_check)
    |> check_history.store(second_check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(first_service),
      timestamp.from_unix_seconds(150),
      timestamp.from_unix_seconds(250),
    )

  assert checks == [first_check]
}

pub fn for_service_between_preserves_newest_first_order_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let oldest_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
    )

  let middle_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(200),
    )

  let newest_check =
    create_check(
      service.id(monitored_service),
      timestamp.from_unix_seconds(300),
    )

  let history =
    check_history.new()
    |> check_history.store(oldest_check)
    |> check_history.store(middle_check)
    |> check_history.store(newest_check)

  let checks =
    check_history.for_service_between(
      history,
      service.id(monitored_service),
      timestamp.from_unix_seconds(100),
      timestamp.from_unix_seconds(300),
    )

  assert checks
    == [
      newest_check,
      middle_check,
      oldest_check,
    ]
}
