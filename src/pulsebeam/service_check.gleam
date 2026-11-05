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

pub fn check(monitored_service: service.Service) -> ServiceCheck {
  let url = service.url(monitored_service)
  let checked_at = timestamp.system_time()

  case request.to(url) {
    Error(_) ->
      from_result(monitored_service, checked_at, Error(InvalidRequest), None)

    Ok(req) -> {
      let started_at = timestamp.system_time()
      let response = httpc.send(req)
      let finished_at = timestamp.system_time()

      case response {
        Error(error) ->
          from_result(
            monitored_service,
            checked_at,
            Error(map_http_error(error)),
            None,
          )

        Ok(response) -> {
          let latency =
            timestamp.difference(started_at, finished_at)
            |> duration.to_milliseconds
            |> Some

          from_result(
            monitored_service,
            checked_at,
            Ok(response.status),
            latency,
          )
        }
      }
    }
  }
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

fn map_http_error(error: httpc.HttpError) -> ServiceCheckError {
  case error {
    httpc.ResponseTimeout -> Timeout
    httpc.FailedToConnect(_, _) -> ConnectionFailed
    httpc.InvalidUtf8Response -> InvalidResponse
  }
}
