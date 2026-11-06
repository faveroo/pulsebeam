import gleam/option.{type Option, None}
import gleam/time/timestamp
import pulsebeam/service.{type ServiceId}

pub type ServiceCheckError {
  Timeout
  ConnectionFailed
  InvalidRequest
  InvalidResponse
}

pub type ServiceCheckOutcome {
  HttpResponse(Int)
  Failure(ServiceCheckError)
}

pub type CheckStatus {
  Up
  Down
}

pub type ServiceCheck {
  ServiceCheck(
    service_id: ServiceId,
    checked_at: timestamp.Timestamp,
    latency_ms: Option(Int),
    outcome: ServiceCheckOutcome,
    status: CheckStatus,
  )
}

pub fn from_result(
  monitored_service: service.Service,
  checked_at: timestamp.Timestamp,
  http_result: Result(Int, ServiceCheckError),
  latency_ms: Option(Int),
) -> ServiceCheck {
  let #(outcome, status, latency) = case http_result {
    Ok(code) -> {
      let status = case code == service.expected_status(monitored_service) {
        True -> Up
        False -> Down
      }

      #(HttpResponse(code), status, latency_ms)
    }

    Error(reason) -> #(Failure(reason), Down, None)
  }

  ServiceCheck(
    service_id: service.id(monitored_service),
    checked_at: checked_at,
    latency_ms: latency,
    outcome: outcome,
    status: status,
  )
}

pub fn checked_at(service_check: ServiceCheck) -> timestamp.Timestamp {
  service_check.checked_at
}

pub fn status(service_check: ServiceCheck) -> CheckStatus {
  service_check.status
}

pub fn latency_ms(service_check: ServiceCheck) -> Option(Int) {
  service_check.latency_ms
}

pub fn outcome(service_check: ServiceCheck) -> ServiceCheckOutcome {
  service_check.outcome
}

pub fn service_id(service_check: ServiceCheck) -> ServiceId {
  service_check.service_id
}
