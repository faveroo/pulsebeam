import gleam/dynamic/decode
import gleam/erlang/process
import gleam/result
import pog
import pulsebeam/repository/persistence_error.{
  type PersistenceError, ConnectionFailed, QueryFailed,
}

pub fn start(
  pool_name: process.Name(pog.Message),
  database_url: String,
) -> Result(pog.Connection, PersistenceError) {
  use config <- result.try(
    pog.url_config(pool_name, database_url)
    |> result.map_error(fn(_) { ConnectionFailed }),
  )

  use started <- result.try(
    pog.start(config)
    |> result.map_error(fn(_) { ConnectionFailed }),
  )

  Ok(started.data)
}

pub fn ping(connection: pog.Connection) -> Result(Nil, PersistenceError) {
  let decoder = decode.at([0], decode.int)

  case
    pog.query("SELECT 1")
    |> pog.returning(decoder)
    |> pog.execute(connection)
  {
    Ok(_) -> Ok(Nil)
    Error(pog.ConnectionUnavailable) -> Error(ConnectionFailed)
    Error(_) -> Error(QueryFailed)
  }
}
