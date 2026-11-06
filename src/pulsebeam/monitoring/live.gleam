import pulsebeam/infrastructure/clock/system
import pulsebeam/infrastructure/http/transport
import pulsebeam/monitoring/checker
import pulsebeam/service
import pulsebeam/service_check

pub fn run(monitored_service: service.Service) -> service_check.ServiceCheck {
  let http_transport = transport.new()
  let clock = system.new()

  checker.run(monitored_service, http_transport, clock)
}
