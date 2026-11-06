import gleam/option
import gleam/time/timestamp
import pulsebeam/monitoring/live
import pulsebeam/service
import pulsebeam/service_check

// Temporary live HTTP integration tests, moved from service_check_test.gleam.
// Step 10 will replace the external example.com dependency with a local server.
fn successful_check(
  expected_status: Int,
) -> #(service.Service, service_check.ServiceCheck) {
  let assert Ok(monitored_service) =
    service.new(
      "Example",
      "https://example.com",
      expected_status,
      60,
      service.Community,
    )

  #(monitored_service, live.run(monitored_service))
}

fn failed_connection_check() -> #(service.Service, service_check.ServiceCheck) {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  #(monitored_service, live.run(monitored_service))
}

pub fn successful_check_preserves_service_reference_test() {
  let #(monitored_service, check) = successful_check(200)

  assert service_check.service_id(check) == service.id(monitored_service)
}

pub fn successful_check_records_http_status_test() {
  let #(_, check) = successful_check(200)

  assert service_check.outcome(check) == service_check.HttpResponse(200)
}

pub fn expected_http_status_is_up_test() {
  let #(_, check) = successful_check(200)

  assert service_check.status(check) == service_check.Up
}

pub fn unexpected_http_status_is_down_test() {
  let #(_, check) = successful_check(404)

  assert service_check.status(check) == service_check.Down
  assert service_check.outcome(check) == service_check.HttpResponse(200)
}

pub fn successful_check_records_timestamp_test() {
  let #(_, check) = successful_check(200)

  let #(seconds, _) =
    service_check.checked_at(check)
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn successful_check_records_latency_test() {
  let #(_, check) = successful_check(200)

  let assert option.Some(latency) = service_check.latency_ms(check)

  assert latency >= 0
}

pub fn failed_connection_is_down_test() {
  let #(_, check) = failed_connection_check()

  assert service_check.status(check) == service_check.Down
}

pub fn failed_connection_preserves_reason_test() {
  let #(_, check) = failed_connection_check()

  assert service_check.outcome(check)
    == service_check.Failure(service_check.ConnectionFailed)
}

pub fn failed_connection_has_no_latency_test() {
  let #(_, check) = failed_connection_check()

  assert service_check.latency_ms(check) == option.None
}

pub fn failed_connection_records_timestamp_test() {
  let #(_, check) = failed_connection_check()

  let #(seconds, _) =
    service_check.checked_at(check)
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn failed_connection_preserves_service_reference_test() {
  let #(monitored_service, check) = failed_connection_check()

  assert service_check.service_id(check) == service.id(monitored_service)
}
