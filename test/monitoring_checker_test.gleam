import gleam/erlang/process
import gleam/option.{None, Some}
import gleam/time/timestamp
import pulsebeam/monitoring/checker
import pulsebeam/monitoring/ports
import pulsebeam/service
import pulsebeam/service_check

fn monitored_service() -> service.Service {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  monitored_service
}

fn fake_clock(
  checked_at: timestamp.Timestamp,
  started_at: Int,
  finished_at: Int,
) -> ports.Clock {
  let times = process.new_subject()

  process.send(times, started_at)
  process.send(times, finished_at)

  ports.Clock(now: fn() { checked_at }, monotonic_ms: fn() {
    let assert Ok(value) = process.receive(times, within: 100)
    value
  })
}

pub fn successful_check_uses_monotonic_latency_test() {
  let monitored_service = monitored_service()
  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock = fake_clock(checked_at, 1000, 1042)

  let check = checker.run(monitored_service, transport, clock)

  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)
  assert check.latency_ms == Some(42)
  assert check.checked_at == checked_at
  assert check.service_id == service.id(monitored_service)
}

pub fn unexpected_http_status_is_down_test() {
  let monitored_service = monitored_service()

  let transport = ports.HttpTransport(get: fn(_) { Ok(503) })

  let clock = fake_clock(timestamp.from_unix_seconds(1_700_000_000), 200, 205)

  let check = checker.run(monitored_service, transport, clock)

  assert check.status == service_check.Down
  assert check.outcome == service_check.HttpResponse(503)
  assert check.latency_ms == Some(5)
}

pub fn transport_failure_has_no_latency_test() {
  let monitored_service = monitored_service()

  let transport =
    ports.HttpTransport(get: fn(_) { Error(service_check.Timeout) })

  let clock = fake_clock(timestamp.from_unix_seconds(1_700_000_000), 1000, 1050)

  let check = checker.run(monitored_service, transport, clock)

  assert check.status == service_check.Down
  assert check.outcome == service_check.Failure(service_check.Timeout)
  assert check.latency_ms == None
}
