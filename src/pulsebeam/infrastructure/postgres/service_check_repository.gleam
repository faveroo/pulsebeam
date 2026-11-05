import gleam/dynamic/decode
import gleam/list as gleam_list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import pog
import pulsebeam/repository/persistence_error.{
  type PersistenceError, ConnectionFailed, InvalidPersistedData, QueryFailed,
}
import pulsebeam/service
import pulsebeam/service_check

type CheckRow {
  CheckRow(
    service_id: String,
    checked_at: timestamp.Timestamp,
    status: String,
    http_status: Option(Int),
    latency_ms: Option(Int),
    error_reason: Option(String),
  )
}

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

pub fn for_service(
  connection: pog.Connection,
  service_id: service.ServiceId,
) -> Result(List(service_check.ServiceCheck), PersistenceError) {
  let query =
    pog.query(
      "
      SELECT
        service_id::text,
        (EXTRACT(EPOCH FROM checked_at) * 1000000)::bigint AS checked_at,
        status,
        http_status,
        latency_ms,
        error_reason
      FROM service_checks
      WHERE service_id = $1::uuid
      ORDER BY checked_at DESC, id DESC
      ",
    )
    |> pog.parameter(
      service_id
      |> service.service_id_to_string
      |> pog.text,
    )
    |> pog.returning(check_row_decoder())

  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: rows, ..)) -> gleam_list.try_map(rows, row_to_check)

    Error(pog.ConnectionUnavailable) -> Error(ConnectionFailed)

    Error(pog.UnexpectedResultType(_)) -> Error(InvalidPersistedData)

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

fn check_row_decoder() -> decode.Decoder(CheckRow) {
  use service_id <- decode.field(0, decode.string)
  use checked_at <- decode.field(1, pog.timestamp_decoder())
  use status <- decode.field(2, decode.string)
  use http_status <- decode.field(3, decode.optional(decode.int))
  use latency_ms <- decode.field(4, decode.optional(decode.int))
  use error_reason <- decode.field(5, decode.optional(decode.string))

  decode.success(CheckRow(
    service_id:,
    checked_at:,
    status:,
    http_status:,
    latency_ms:,
    error_reason:,
  ))
}

fn status_from_string(
  value: String,
) -> Result(service_check.CheckStatus, PersistenceError) {
  case value {
    "up" -> Ok(service_check.Up)
    "down" -> Ok(service_check.Down)
    _ -> Error(InvalidPersistedData)
  }
}

fn outcome_from_columns(
  http_status: Option(Int),
  error_reason: Option(String),
) -> Result(service_check.ServiceCheckOutcome, PersistenceError) {
  case http_status, error_reason {
    Some(code), None if code >= 100 && code <= 599 ->
      Ok(service_check.HttpResponse(code))

    None, Some("timeout") -> Ok(service_check.Failure(service_check.Timeout))

    None, Some("connection_failed") ->
      Ok(service_check.Failure(service_check.ConnectionFailed))

    None, Some("invalid_request") ->
      Ok(service_check.Failure(service_check.InvalidRequest))

    None, Some("invalid_response") ->
      Ok(service_check.Failure(service_check.InvalidResponse))

    _, _ -> Error(InvalidPersistedData)
  }
}

fn row_to_check(
  row: CheckRow,
) -> Result(service_check.ServiceCheck, PersistenceError) {
  use service_id <- result.try(
    service.service_id_from_string(row.service_id)
    |> result.map_error(fn(_) { InvalidPersistedData }),
  )

  use status <- result.try(status_from_string(row.status))

  use outcome <- result.try(outcome_from_columns(
    row.http_status,
    row.error_reason,
  ))

  case outcome, status {
    service_check.Failure(_), service_check.Up -> Error(InvalidPersistedData)

    _, _ ->
      Ok(service_check.ServiceCheck(
        service_id: service_id,
        checked_at: row.checked_at,
        latency_ms: row.latency_ms,
        outcome: outcome,
        status: status,
      ))
  }
}
