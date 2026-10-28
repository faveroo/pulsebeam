import gleam/http/request
import gleam/httpc
import gleam/option.{type Option, None, Some}
import gleam/time/duration
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

pub fn check(service: service.Service) -> ServiceCheck {
  let url = service.url(service)
  let checked_at = timestamp.system_time()

  case request.to(url) {
    Error(_) ->
      ServiceCheck(
        service_id: service.id(service),
        checked_at: checked_at,
        latency_ms: None,
        outcome: Failure(InvalidRequest),
        status: Down,
      )

    Ok(req) -> {
      let started_at = timestamp.system_time()
      let response = httpc.send(req)
      let finished_at = timestamp.system_time()

      case response {
        Error(error) ->
          ServiceCheck(
            service_id: service.id(service),
            checked_at: checked_at,
            latency_ms: None,
            outcome: Failure(map_http_error(error)),
            status: Down,
          )

        Ok(response) -> {
          let latency =
            timestamp.difference(started_at, finished_at)
            |> duration.to_milliseconds
            |> Some

          let status = case
            response.status == service.expected_status(service)
          {
            True -> Up
            False -> Down
          }

          ServiceCheck(
            service_id: service.id(service),
            checked_at: checked_at,
            latency_ms: latency,
            outcome: HttpResponse(response.status),
            status: status,
          )
        }
      }
    }
  }
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

fn map_http_error(error: httpc.HttpError) -> ServiceCheckError {
  case error {
    httpc.ResponseTimeout -> Timeout
    httpc.FailedToConnect(_, _) -> ConnectionFailed
    httpc.InvalidUtf8Response -> InvalidResponse
  }
}
