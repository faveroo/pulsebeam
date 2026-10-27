import gleam/http/request
import gleam/httpc
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
  ServiceCheck(checked_at: timestamp.Timestamp, outcome: ServiceCheckOutcome)
}

pub fn check(service: service.Service) -> ServiceCheck {
  let url = service.url(service)
  let checked_at = timestamp.system_time()

  case request.to(url) {
    Error(_) ->
      ServiceCheck(checked_at: checked_at, outcome: Failure(InvalidRequest))

    Ok(req) ->
      case httpc.send(req) {
        Error(_) ->
          ServiceCheck(checked_at: checked_at, outcome: Failure(HttpError))

        Ok(response) ->
          ServiceCheck(
            checked_at: checked_at,
            outcome: HttpResponse(response.status),
          )
      }
  }
}

pub fn checked_at(service_check: ServiceCheck) -> timestamp.Timestamp {
  service_check.checked_at
}

pub fn outcome(service_check: ServiceCheck) -> ServiceCheckOutcome {
    service_check.outcome
}
