import gleam/http/request
import gleam/httpc
import gleam/option.{type Option, None, Some}
import gleam/time/duration
import gleam/time/timestamp
import pulsebeam/service

pub type ServiceCheckError {
  HttpError
  InvalidRequest
}

pub type ServiceCheckOutcome {
  HttpResponse(Int)
  Failure(ServiceCheckError)
}

pub type ServiceCheck {
  ServiceCheck(
    checked_at: timestamp.Timestamp,
    latency_ms: Option(Int),
    outcome: ServiceCheckOutcome,
  )
}

pub fn check(service: service.Service) -> ServiceCheck {
  let url = service.url(service)
  let checked_at = timestamp.system_time()

  case request.to(url) {
    Error(_) ->
      ServiceCheck(
        checked_at: checked_at,
        latency_ms: None,
        outcome: Failure(InvalidRequest),
      )

    Ok(req) -> {
      let started_at = timestamp.system_time()
      let response = httpc.send(req)
      let finished_at = timestamp.system_time()

      case response {
        Error(_) ->
          ServiceCheck(
            checked_at: checked_at,
            latency_ms: None,
            outcome: Failure(HttpError),
          )

        Ok(response) -> {
          let latency =
            timestamp.difference(started_at, finished_at)
            |> duration.to_milliseconds
            |> Some

          ServiceCheck(
            checked_at: checked_at,
            latency_ms: latency,
            outcome: HttpResponse(response.status),
          )
        }
      }
    }
  }
}

pub fn checked_at(service_check: ServiceCheck) -> timestamp.Timestamp {
  service_check.checked_at
}

pub fn latency_ms(service_check: ServiceCheck) -> Option(Int) {
  service_check.latency_ms
}

pub fn outcome(service_check: ServiceCheck) -> ServiceCheckOutcome {
  service_check.outcome
}
