import gleam/option.{None, Some}
import pulsebeam/monitoring/ports
import pulsebeam/service
import pulsebeam/service_check

pub fn run(
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
) -> service_check.ServiceCheck {
  let checked_at = clock.now()

  let started_at = clock.monotonic_ms()

  let result = transport.get(service.url(monitored_service))

  let finished_at = clock.monotonic_ms()

  let latency_ms = case result {
    Ok(_) -> Some(finished_at - started_at)
    Error(_) -> None
  }

  service_check.from_result(monitored_service, checked_at, result, latency_ms)
}
