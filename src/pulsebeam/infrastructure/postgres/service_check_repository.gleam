import gleam/option.{type Option, None, Some}
import pog
import pulsebeam/repository/persistence_error.{
  type PersistenceError, ConnectionFailed, QueryFailed,
}
import pulsebeam/service
import pulsebeam/service_check

pub fn store(
  connection: pog.Connection,
  check: service_check.ServiceCheck,
) -> Result(Nil, PersistenceError) {
  let #(http_status, error_reason) = outcome_to_columns(check.outcome)

  let query =
    pog.query(
      "
        INSERT INTO service_checks (
            service_id,
            checked_at,
            status,
            http_status,
            latency_ms,
            error_reason
        )
        VALUES ($1::uuid, $2, $3, $4, $5, $6)
        ",
    )
    |> pog.parameter(
      check.service_id
      |> service.service_id_to_string
      |> pog.text,
    )
    |> pog.parameter(pog.timestamp(check.checked_at))
    |> pog.parameter(pog.text(status_to_string(check.status)))
    |> pog.parameter(pog.nullable(pog.int, http_status))
    |> pog.parameter(pog.nullable(pog.int, check.latency_ms))
    |> pog.parameter(pog.nullable(pog.text, error_reason))

  case pog.execute(query, connection) {
    Ok(_) -> Ok(Nil)

    Error(pog.ConnectionUnavailable) -> Error(ConnectionFailed)

    Error(_) -> Error(QueryFailed)
  }
}

fn status_to_string(status: service_check.CheckStatus) -> String {
  case status {
    service_check.Up -> "up"
    service_check.Down -> "down"
  }
}

fn outcome_to_columns(
  outcome: service_check.ServiceCheckOutcome,
) -> #(Option(Int), Option(String)) {
  case outcome {
    service_check.HttpResponse(code) -> #(Some(code), None)

    service_check.Failure(error) -> #(None, Some(error_to_string(error)))
  }
}

fn error_to_string(error: service_check.ServiceCheckError) -> String {
  case error {
    service_check.Timeout -> "timeout"
    service_check.ConnectionFailed -> "connection_failed"
    service_check.InvalidRequest -> "invalid_request"
    service_check.InvalidResponse -> "invalid_response"
  }
}
