import gleam/option
import gleam/time/timestamp
import pulsebeam/service
import pulsebeam/service_check

// Pure domain tests. No HTTP requests or system-clock dependencies.
fn monitored_service() -> service.Service {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  monitored_service
}

pub fn expected_response_is_classified_as_up_test() {
  let monitored_service = monitored_service()
  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let check =
    service_check.from_result(
      monitored_service,
      checked_at,
      Ok(200),
      option.Some(42),
    )

  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)
  assert check.latency_ms == option.Some(42)
  assert check.checked_at == checked_at
  assert check.service_id == service.id(monitored_service)
}

pub fn unexpected_response_is_classified_as_down_test() {
  let check =
    service_check.from_result(
      monitored_service(),
      timestamp.from_unix_seconds(1_700_000_000),
      Ok(503),
      option.Some(30),
    )

  assert check.status == service_check.Down
  assert check.outcome == service_check.HttpResponse(503)
  assert check.latency_ms == option.Some(30)
}

pub fn transport_failure_is_classified_as_down_test() {
  let check =
    service_check.from_result(
      monitored_service(),
      timestamp.from_unix_seconds(1_700_000_000),
      Error(service_check.Timeout),
      option.Some(30),
    )

  assert check.status == service_check.Down
  assert check.outcome == service_check.Failure(service_check.Timeout)
  assert check.latency_ms == option.None
}
