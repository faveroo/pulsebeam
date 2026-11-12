import gleam/option.{type Option, None, Some}
import pulsebeam/monitoring/checker
import pulsebeam/monitoring/ports
import pulsebeam/service
import pulsebeam/service_check

pub fn run(
  requested_id: service.ServiceId,
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
) -> Option(service_check.ServiceCheck) {
  case requested_id == service.id(monitored_service) {
    True -> checker.run(monitored_service, transport, clock) |> Some

    False -> None
  }
}
