import gleam/erlang/process
import gleam/result
import pog
import pulsebeam/infrastructure/clock/system
import pulsebeam/infrastructure/http/transport
import pulsebeam/infrastructure/postgres/service_check_repository
import pulsebeam/monitoring/check_consumer
import pulsebeam/monitoring/check_persister
import pulsebeam/monitoring/completion_relay
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/scheduler
import pulsebeam/repository/persistence_error
import pulsebeam/service
import pulsebeam/service_check

pub opaque type Runtime {
  Runtime(
    monitored_service_id: service.ServiceId,
    scheduler_commands: process.Subject(scheduler.Command),
    consumer_commands: process.Subject(check_consumer.Command),
    persister_commands: process.Subject(check_persister.Command),
    relay: completion_relay.Relay,
  )
}

pub type ShutdownError {
  SchedulerStopTimedOut
  ConsumerStopTimedOut
  PersisterStopTimedOut
  RelayStopTimedOut
}

pub fn start(
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Result(Runtime, Nil) {
  case service.is_enabled(monitored_service) {
    False -> Error(Nil)

    True -> start_enabled(monitored_service, transport, clock, store, outcomes)
  }
}

fn start_enabled(
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Result(Runtime, Nil) {
  case completion_relay.start(service.id(monitored_service)) {
    Error(_) -> Error(Nil)

    Ok(relay) -> {
      let on_finished = fn(service_id) {
        completion_relay.finished(relay, service_id)
      }

      case check_persister.start_with_completion(store, outcomes, on_finished) {
        Error(_) -> {
          let _ = completion_relay.stop_and_wait(relay)
          Error(Nil)
        }

        Ok(#(checks, persister_commands)) ->
          case
            check_consumer.start(monitored_service, transport, clock, checks)
          {
            Error(_) -> {
              let _ = check_persister.stop_and_wait(persister_commands)
              let _ = completion_relay.stop_and_wait(relay)
              Error(Nil)
            }

            Ok(#(events, consumer_commands)) ->
              case scheduler.start_with_completion(monitored_service, events) {
                Error(_) -> {
                  let _ = check_consumer.stop_and_wait(consumer_commands)
                  let _ = check_persister.stop_and_wait(persister_commands)
                  let _ = completion_relay.stop_and_wait(relay)
                  Error(Nil)
                }

                Ok(scheduler_commands) -> {
                  completion_relay.bind(relay, scheduler_commands)

                  Ok(Runtime(
                    monitored_service_id: service.id(monitored_service),
                    scheduler_commands:,
                    consumer_commands:,
                    persister_commands:,
                    relay:,
                  ))
                }
              }
          }
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

pub fn stop(running: Runtime) -> Nil {
  let _ = stop_and_wait(running)
  Nil
}

pub fn stop_and_wait(running: Runtime) -> Result(Nil, ShutdownError) {
  // The scheduler sends its barrier from its own process, after all checks.
  let consumer_barrier = fn(reply) {
    check_consumer.drain(running.consumer_commands, reply)
  }

  case scheduler.stop_and_drain(running.scheduler_commands, consumer_barrier) {
    Error(_) -> Error(SchedulerStopTimedOut)

    Ok(Nil) -> {
      // The consumer sends the persister barrier only after all HTTP results.
      let persister_barrier = fn(reply) {
        check_persister.drain(running.persister_commands, reply)
      }

      case check_consumer.stop_and_drain(
        running.consumer_commands,
        persister_barrier,
      ) {
        Error(_) -> Error(ConsumerStopTimedOut)

        Ok(Nil) ->
          case check_persister.stop_and_wait(running.persister_commands) {
            Error(_) -> Error(PersisterStopTimedOut)

            Ok(Nil) ->
              case completion_relay.stop_and_wait(running.relay) {
                Error(_) -> Error(RelayStopTimedOut)
                Ok(Nil) -> Ok(Nil)
              }
          }
      }
    }
  }
}

// Process IDs are used by the application to monitor abnormal or unexpected
// termination. Monitoring alone does not restart a failed component.
pub fn process_ids(running: Runtime) -> Result(List(process.Pid), Nil) {
  use scheduler_pid <- result.try(process.subject_owner(running.scheduler_commands))
  use consumer_pid <- result.try(process.subject_owner(running.consumer_commands))
  use persister_pid <- result.try(process.subject_owner(running.persister_commands))
  use relay_pid <- result.try(completion_relay.owner_pid(running.relay))
  Ok([scheduler_pid, consumer_pid, persister_pid, relay_pid])
}

pub fn service_id(running: Runtime) -> service.ServiceId {
  running.monitored_service_id
}
