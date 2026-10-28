import gleam/option
import gleam/time/timestamp
import pulsebeam/service
import pulsebeam/service_check

pub fn successful_check_records_http_status_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = service_check.check(monitored_service)

  assert service_check.outcome(check) == service_check.HttpResponse(200)
}

pub fn successful_check_records_timestamp_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = service_check.check(monitored_service)

  let #(seconds, _) =
    service_check.checked_at(check)
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn successful_check_records_latency_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let check = service_check.check(monitored_service)

  let assert option.Some(latency) = service_check.latency_ms(check)

  assert latency >= 0
}

pub fn failed_connection_creates_check_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = service_check.check(monitored_service)

  assert service_check.outcome(check)
    == service_check.Failure(service_check.HttpError)
}

pub fn failed_connection_has_no_latency_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = service_check.check(monitored_service)

  assert service_check.latency_ms(check) == option.None
}

pub fn failed_connection_still_records_timestamp_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = service_check.check(monitored_service)

  let #(seconds, _) =
    service_check.checked_at(check)
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}
