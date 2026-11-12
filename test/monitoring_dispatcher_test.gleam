import gleam/option.{None, Some}
import gleam/time/timestamp
import pulsebeam/monitoring/dispatcher
import pulsebeam/monitoring/ports
import pulsebeam/service
import pulsebeam/service_check

fn monitored_service_fn() -> service.Service {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  monitored_service
}

fn fake_clock() -> ports.Clock {
  ports.Clock(
    now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
    monotonic_ms: fn() { 1000 },
  )
}

pub fn matching_service_executes_check_test() {
  let monitored_service = monitored_service_fn()

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let result =
    dispatcher.run(
      service.id(monitored_service),
      monitored_service,
      transport,
      fake_clock(),
    )

  let assert Some(check) = result

  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)
  assert check.service_id == service.id(monitored_service)
}

pub fn different_service_is_ignored_test() {
  let monitored_service = monitored_service_fn()
  let another_service = monitored_service_fn()

  let transport =
    ports.HttpTransport(get: fn(_) { panic as "HTTP should not be called" })

  let result =
    dispatcher.run(
      service.id(another_service),
      monitored_service,
      transport,
      fake_clock(),
    )

  assert result == None
}
