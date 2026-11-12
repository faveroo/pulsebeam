import gleam/erlang/process
import gleam/list
import gleam/result
import pog
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/monitoring/runtime
import pulsebeam/repository/persistence_error
import pulsebeam/service

pub type BootstrapError {
  LoadFailed(persistence_error.PersistenceError)
  RuntimeStartFailed
}

pub fn enabled_services(
  services: List(service.Service),
) -> List(service.Service) {
  list.filter(services, service.is_enabled)
}

pub fn load_enabled_services(
  load: fn() ->
    Result(List(service.Service), persistence_error.PersistenceError),
) -> Result(List(service.Service), persistence_error.PersistenceError) {
  load()
  |> result.map(enabled_services)
}

pub fn load_enabled_from_database(
  database: pog.Connection,
) -> Result(List(service.Service), persistence_error.PersistenceError) {
  load_enabled_services(fn() { service_repository.list(database) })
}

pub fn start_enabled_services(
  services: List(service.Service),
  start: fn(service.Service) -> Result(a, e),
  stop: fn(a) -> Nil,
) -> Result(List(a), e) {
  let enabled = enabled_services(services)

  start_services(enabled, start, stop, [])
}

fn start_services(
  remaining: List(service.Service),
  start: fn(service.Service) -> Result(a, e),
  stop: fn(a) -> Nil,
  started: List(a),
) -> Result(List(a), e) {
  case remaining {
    [] -> Ok(list.reverse(started))

    [monitored_service, ..rest] -> {
      case start(monitored_service) {
        Ok(running) -> start_services(rest, start, stop, [running, ..started])

        Error(error) -> {
          list.each(started, stop)

          Error(error)
        }
      }
    }
  }
}

pub fn start_loaded_services(
  load: fn() -> Result(List(service.Service), e),
  start: fn(service.Service) -> Result(a, e),
  stop: fn(a) -> Nil,
) -> Result(List(a), e) {
  case load() {
    Error(error) -> Error(error)

    Ok(services) -> start_enabled_services(services, start, stop)
  }
}

pub fn start_live_from_database(
  database: pog.Connection,
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Result(List(runtime.Runtime), BootstrapError) {
  let load = fn() {
    load_enabled_from_database(database)
    |> result.map_error(LoadFailed)
  }

  let start = fn(monitored_service) {
    runtime.start_live(monitored_service, database, outcomes)
    |> result.map_error(fn(_) { RuntimeStartFailed })
  }

  start_loaded_services(load, start, runtime.stop)
}
