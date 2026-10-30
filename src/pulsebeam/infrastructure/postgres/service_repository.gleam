import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import pulsebeam/repository/persistence_error.{
  type PersistenceError, Conflict, ConnectionFailed, InvalidPersistedData,
  QueryFailed,
}
import pulsebeam/service

pub fn insert(
  connection: pog.Connection,
  monitored_service: service.Service,
) -> Result(Nil, PersistenceError) {
  let query =
    pog.query(
      "
      INSERT INTO services (
        id,
        name,
        url,
        expected_status,
        interval_seconds,
        enabled,
        visibility
      )
      VALUES ($1::uuid, $2, $3, $4, $5, $6, $7)
      ",
    )
    |> pog.parameter(
      monitored_service
      |> service.id
      |> service.service_id_to_string
      |> pog.text,
    )
    |> pog.parameter(pog.text(service.name(monitored_service)))
    |> pog.parameter(pog.text(service.url(monitored_service)))
    |> pog.parameter(pog.int(service.expected_status(monitored_service)))
    |> pog.parameter(pog.int(service.interval_seconds(monitored_service)))
    |> pog.parameter(pog.bool(service.is_enabled(monitored_service)))
    |> pog.parameter(
      pog.text(visibility_to_string(service.visibility(monitored_service))),
    )

  case pog.execute(query, connection) {
    Ok(_) -> Ok(Nil)

    Error(pog.ConnectionUnavailable) -> Error(ConnectionFailed)

    Error(pog.ConstraintViolated(_, constraint, _)) ->
      case constraint == "services_pkey" {
        True -> Error(Conflict)
        False -> Error(QueryFailed)
      }

    Error(_) -> Error(QueryFailed)
  }
}

fn visibility_to_string(visibility: service.Visibility) -> String {
  case visibility {
    service.Community -> "community"
    service.Private -> "private"
  }
}

fn service_row_decoder() -> decode.Decoder(ServiceRow) {
  use id <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use url <- decode.field(2, decode.string)
  use expected_status <- decode.field(3, decode.int)
  use interval_seconds <- decode.field(4, decode.int)
  use enabled <- decode.field(5, decode.bool)
  use visibility <- decode.field(6, decode.string)

  decode.success(ServiceRow(
    id:,
    name:,
    url:,
    expected_status:,
    interval_seconds:,
    enabled:,
    visibility:,
  ))
}

type ServiceRow {
  ServiceRow(
    id: String,
    name: String,
    url: String,
    expected_status: Int,
    interval_seconds: Int,
    enabled: Bool,
    visibility: String,
  )
}

fn visibility_from_string(
  value: String,
) -> Result(service.Visibility, PersistenceError) {
  case value {
    "community" -> Ok(service.Community)

    "private" -> Ok(service.Private)

    _ -> Error(InvalidPersistedData)
  }
}

fn row_to_service(
  row: ServiceRow,
) -> Result(service.Service, PersistenceError) {
  let ServiceRow(
    id,
    name,
    url,
    expected_status,
    interval_seconds,
    enabled,
    visibility,
  ) = row

  let assert Ok(service_id) =
    service.service_id_from_string(id)
    |> result.map_error(fn(_) { InvalidPersistedData })

  let assert Ok(service_visibility) = visibility_from_string(visibility)

  service.reconstitute(
    service_id,
    name,
    url,
    expected_status,
    interval_seconds,
    enabled,
    service_visibility,
  )
  |> result.map_error(fn(_) { InvalidPersistedData })
}

pub fn find_by_id(
  connection: pog.Connection,
  id: service.ServiceId,
) -> Result(Option(service.Service), PersistenceError) {
  let query =
    pog.query(
      "
      SELECT
        id::text,
        name,
        url,
        expected_status,
        interval_seconds,
        enabled,
        visibility
      FROM services
      WHERE id = $1::uuid
      LIMIT 1
      ",
    )
    |> pog.parameter(
      id
      |> service.service_id_to_string
      |> pog.text,
    )
    |> pog.returning(service_row_decoder())

  case pog.execute(query, connection) {
    Ok(pog.Returned(rows: [], ..)) -> Ok(None)

    Ok(pog.Returned(rows: [row, ..], ..)) ->
      case row_to_service(row) {
        Ok(monitored_service) -> Ok(Some(monitored_service))

        Error(error) -> Error(error)
      }

    Error(pog.ConnectionUnavailable) -> Error(ConnectionFailed)

    Error(pog.UnexpectedResultType(_)) -> Error(InvalidPersistedData)

    Error(_) -> Error(QueryFailed)
  }
}

pub fn update(
  connection: pog.Connection,
  monitored_service: service.Service,
) -> Result(Nil, PersistenceError) {
  let query =
    pog.query(
      "
      UPDATE services
      SET
        name = $2,
        url = $3,
        expected_status = $4,
        interval_seconds = $5,
        enabled = $6,
        visibility = $7
      WHERE id = $1::uuid
      ",
    )
    |> pog.parameter(
      monitored_service
      |> service.id
      |> service.service_id_to_string
      |> pog.text,
    )
    |> pog.parameter(pog.text(service.name(monitored_service)))
    |> pog.parameter(pog.text(service.url(monitored_service)))
    |> pog.parameter(pog.int(service.expected_status(monitored_service)))
    |> pog.parameter(pog.int(service.interval_seconds(monitored_service)))
    |> pog.parameter(pog.bool(service.is_enabled(monitored_service)))
    |> pog.parameter(
      pog.text(
        visibility_to_string(
          service.visibility(monitored_service),
        ),
      ),
    )

  case pog.execute(query, connection) {
    Ok(_) ->
      Ok(Nil)

    Error(pog.ConnectionUnavailable) ->
      Error(ConnectionFailed)

    Error(_) ->
      Error(QueryFailed)
  }
}