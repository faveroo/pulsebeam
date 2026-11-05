import envoy
import gleam/erlang/process
import pog
import pulsebeam/infrastructure/postgres/connection
import pulsebeam/repository/persistence_error

fn wait_until_ready(
  database: pog.Connection,
  attempts_remaining: Int,
) -> Result(Nil, persistence_error.PersistenceError) {
  case connection.ping(database) {
    Ok(Nil) -> Ok(Nil)

    Error(persistence_error.ConnectionFailed) if attempts_remaining > 1 -> {
      process.sleep(100)
      wait_until_ready(database, attempts_remaining - 1)
    }

    Error(error) -> Error(error)
  }
}

pub fn database() -> pog.Connection {
  let assert Ok(database_url) = envoy.get("PULSEBEAM_DATABASE_URL")

  let pool_name = process.new_name("pulsebeam_repository_test")

  let assert Ok(config) = pog.url_config(pool_name, database_url)

  let config = pog.pool_size(config, 1)

  let assert Ok(started) = pog.start(config)

  let database = started.data

  let assert Ok(Nil) = wait_until_ready(database, 10)

  database
}
