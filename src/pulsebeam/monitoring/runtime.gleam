import gleam/erlang/process
import pog
import pulsebeam/infrastructure/clock/system
import pulsebeam/infrastructure/http/transport
import pulsebeam/infrastructure/postgres/service_check_repository
import pulsebeam/monitoring/check_consumer
import pulsebeam/monitoring/check_persister
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/scheduler
import pulsebeam/repository/persistence_error
import pulsebeam/service
import pulsebeam/service_check

pub opaque type Runtime {
  Runtime(
    scheduler_commands: process.Subject(scheduler.Command),
    consumer_commands: process.Subject(check_consumer.Command),
    persister_commands: process.Subject(check_persister.Command),
  )
}

pub type ShutdownError {
  SchedulerStopTimedOut
  ConsumerStopTimedOut
  PersisterStopTimedOut
}

pub fn start(
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Result(Runtime, Nil) {
  case check_persister.start(store, outcomes) {
    Error(_) -> Error(Nil)

    Ok(#(checks, persister_commands)) ->
      case check_consumer.start(monitored_service, transport, clock, checks) {
        Error(_) -> {
          check_persister.stop(persister_commands)
          Error(Nil)
        }

        Ok(#(events, consumer_commands)) ->
          case scheduler.start(monitored_service, events) {
            Error(_) -> {
              check_consumer.stop(consumer_commands)
              check_persister.stop(persister_commands)
              Error(Nil)
            }
            Ok(scheduler_commands) ->
              Ok(Runtime(
                scheduler_commands:,
                consumer_commands:,
                persister_commands:,
              ))
          }
      }
  }
}

pub fn start_live(
  monitored_service: service.Service,
  database: pog.Connection,
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Result(Runtime, Nil) {
  let store = fn(check) { service_check_repository.store(database, check) }

  start(monitored_service, transport.new(), system.new(), store, outcomes)
}

pub fn stop(runtime: Runtime) -> Nil {
  scheduler.stop(runtime.scheduler_commands)
  check_consumer.stop(runtime.consumer_commands)
  check_persister.stop(runtime.persister_commands)
}

pub fn stop_and_wait(running: Runtime) -> Result(Nil, ShutdownError) {
  case scheduler.stop_and_wait(running.scheduler_commands) {
    Error(_) -> Error(SchedulerStopTimedOut)

    Ok(Nil) ->
      case check_consumer.stop_and_wait(running.consumer_commands) {
        Error(_) -> Error(ConsumerStopTimedOut)

        Ok(Nil) ->
          case check_persister.stop_and_wait(running.persister_commands) {
            Error(_) -> Error(PersisterStopTimedOut)
            Ok(Nil) -> Ok(Nil)
          }
      }
  }
}
