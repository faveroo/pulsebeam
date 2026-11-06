import gleam/int
import gleam/option
import gleam/time/timestamp
import pulsebeam/infrastructure/http/transport
import pulsebeam/monitoring/live
import pulsebeam/service
import pulsebeam/service_check
import support/http_server

fn local_url(status: Int) -> String {
  let assert Ok(port) = http_server.start(status)

  "http://127.0.0.1:" <> int.to_string(port) <> "/"
}

fn run_http_check(
  expected_status: Int,
  response_status: Int,
) -> #(service.Service, service_check.ServiceCheck) {
  let assert Ok(monitored_service) =
    service.new(
      "HTTP Integration Test",
      local_url(response_status),
      expected_status,
      60,
      service.Private,
    )

  #(monitored_service, live.run(monitored_service))
}

pub fn successful_http_check_preserves_result_test() {
  let #(monitored_service, check) = run_http_check(200, 200)

  assert check.service_id == service.id(monitored_service)
  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)

  let assert option.Some(latency) = check.latency_ms
  assert latency >= 0

  let #(seconds, _) =
    check.checked_at
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn unexpected_http_status_is_down_test() {
  let #(_, check) = run_http_check(404, 200)

  assert check.status == service_check.Down
  assert check.outcome == service_check.HttpResponse(200)
}

pub fn http_503_is_down_but_not_transport_failure_test() {
  let #(_, check) = run_http_check(200, 503)

  assert check.status == service_check.Down
  assert check.outcome == service_check.HttpResponse(503)
}

pub fn connection_failure_preserves_result_test() {
  let assert Ok(monitored_service) =
    service.new("Unavailable", "http://127.0.0.1:1", 200, 60, service.Private)

  let check = live.run(monitored_service)

  assert check.service_id == service.id(monitored_service)
  assert check.status == service_check.Down
  assert check.outcome == service_check.Failure(service_check.ConnectionFailed)
  assert check.latency_ms == option.None

  let #(seconds, _) =
    check.checked_at
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0
}

pub fn transport_returns_http_200_test() {
  let http = transport.new()

  assert http.get(local_url(200)) == Ok(200)
}

pub fn transport_returns_http_503_test() {
  let http = transport.new()

  assert http.get(local_url(503)) == Ok(503)
}
