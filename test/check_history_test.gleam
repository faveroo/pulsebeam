import gleam/option
import gleam/time/timestamp
import pulsebeam/check_history
import pulsebeam/service
import pulsebeam/service_check

fn create_check() -> service_check.ServiceCheck {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  service_check.ServiceCheck(
    service_id: service.id(monitored_service),
    checked_at: timestamp.system_time(),
    latency_ms: option.None,
    outcome: service_check.Failure(service_check.ConnectionFailed),
    status: service_check.Down,
  )
}

pub fn new_history_starts_empty_test() {
  let history = check_history.new()

  assert check_history.size(history) == 0
}

pub fn storing_one_check_increases_size_test() {
  let history = check_history.new()
  let check = create_check()

  let history = check_history.store(history, check)

  assert check_history.size(history) == 1
}

pub fn storing_multiple_checks_increases_size_test() {
  let history = check_history.new()

  let first_check = create_check()
  let second_check = create_check()
  let third_check = create_check()

  let history =
    history
    |> check_history.store(first_check)
    |> check_history.store(second_check)
    |> check_history.store(third_check)

  assert check_history.size(history) == 3
}

pub fn storing_check_does_not_modify_original_history_test() {
  let original_history = check_history.new()
  let check = create_check()

  let updated_history = check_history.store(original_history, check)

  assert check_history.size(original_history) == 0
  assert check_history.size(updated_history) == 1
}

pub fn latest_on_empty_history_returns_none_test() {
  let history = check_history.new()

  assert check_history.latest(history) == option.None
}

pub fn latest_returns_stored_check_test() {
  let history = check_history.new()
  let check = create_check()

  let history = check_history.store(history, check)

  assert check_history.latest(history) == option.Some(check)
}

pub fn latest_returns_most_recent_check_test() {
  let history = check_history.new()

  let first_check = create_check()
  let second_check = create_check()

  let history =
    history
    |> check_history.store(first_check)
    |> check_history.store(second_check)

  assert check_history.latest(history) == option.Some(second_check)
}

pub fn latest_preserves_check_data_test() {
  let check = create_check()

  let history =
    check_history.new()
    |> check_history.store(check)

  let assert option.Some(stored_check) = check_history.latest(history)

  assert service_check.service_id(stored_check)
    == service_check.service_id(check)

  assert service_check.status(stored_check) == service_check.status(check)

  assert service_check.outcome(stored_check) == service_check.outcome(check)

  assert service_check.latency_ms(stored_check)
    == service_check.latency_ms(check)

  assert service_check.checked_at(stored_check)
    == service_check.checked_at(check)
}
