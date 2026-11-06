import gleam/option
import gleam/time/timestamp
import pulsebeam/monitoring/live
import pulsebeam/service
import pulsebeam/service_check

pub fn successful_check_preserves_service_reference_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = live.run(monitored_service)

  assert service_check.service_id(check) == service.id(monitored_service)
}

pub fn successful_check_records_http_status_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = live.run(monitored_service)

  assert service_check.outcome(check) == service_check.HttpResponse(200)
}

pub fn expected_http_status_is_up_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = live.run(monitored_service)

  assert service_check.status(check) == service_check.Up
}

pub fn unexpected_http_status_is_down_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 404, 60, service.Community)

  let check = live.run(monitored_service)

  assert service_check.status(check) == service_check.Down
  assert service_check.outcome(check) == service_check.HttpResponse(200)
}

pub fn successful_check_records_timestamp_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = live.run(monitored_service)

  let #(seconds, _) =
    service_check.checked_at(check)
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn successful_check_records_latency_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = live.run(monitored_service)

  let assert option.Some(latency) = service_check.latency_ms(check)

  assert latency >= 0
}

pub fn failed_connection_is_down_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = live.run(monitored_service)

  assert service_check.status(check) == service_check.Down
}

pub fn failed_connection_preserves_reason_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = live.run(monitored_service)

  assert service_check.outcome(check)
    == service_check.Failure(service_check.ConnectionFailed)
}

pub fn failed_connection_has_no_latency_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = live.run(monitored_service)

  assert service_check.latency_ms(check) == option.None
}

pub fn failed_connection_records_timestamp_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = live.run(monitored_service)

  let #(seconds, _) =
    service_check.checked_at(check)
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn failed_connection_preserves_service_reference_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = live.run(monitored_service)

  assert service_check.service_id(check) == service.id(monitored_service)
}

pub fn expected_response_is_classified_as_up_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

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
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  let check =
    service_check.from_result(
      monitored_service,
      timestamp.from_unix_seconds(1_700_000_000),
      Ok(503),
      option.Some(30),
    )

  assert check.status == service_check.Down
  assert check.outcome == service_check.HttpResponse(503)
  assert check.latency_ms == option.Some(30)
}

pub fn transport_failure_is_classified_as_down_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  let check =
    service_check.from_result(
      monitored_service,
      timestamp.from_unix_seconds(1_700_000_000),
      Error(service_check.Timeout),
      option.Some(30),
    )

  assert check.status == service_check.Down
  assert check.outcome == service_check.Failure(service_check.Timeout)
  assert check.latency_ms == option.None
}
