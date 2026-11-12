import gleam/erlang/process
import pulsebeam/repository/persistence_error
import pulsebeam/service
import pulsebeam/service_check

pub opaque type Command {
  Stop
  StopAndWait(process.Subject(Nil))
  Drain(process.Subject(Nil))
}

type Message {
  Persist(service_check.ServiceCheck)
  Shutdown
  ShutdownAndWait(process.Subject(Nil))
  Drained(process.Subject(Nil))
}

pub fn start(
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Result(
  #(process.Subject(service_check.ServiceCheck), process.Subject(Command)),
  Nil,
) {
  start_with_completion(store, outcomes, fn(_) { Nil })
}

pub fn start_with_completion(
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
  on_finished: fn(service.ServiceId) -> Nil,
) -> Result(
  #(process.Subject(service_check.ServiceCheck), process.Subject(Command)),
  Nil,
) {
  let started = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      let checks = process.new_subject()
      let commands = process.new_subject()

      process.send(started, #(checks, commands))

      loop(store, checks, commands, outcomes, on_finished)
    })

  process.receive(started, within: 1000)
}

fn loop(
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  checks: process.Subject(service_check.ServiceCheck),
  commands: process.Subject(Command),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
  on_finished: fn(service.ServiceId) -> Nil,
) -> Nil {
  let selector =
    process.new_selector()
    |> process.select_map(checks, Persist)
    |> process.select_map(commands, fn(command) {
      case command {
        Stop -> Shutdown
        StopAndWait(reply) -> ShutdownAndWait(reply)
        Drain(reply) -> Drained(reply)
      }
    })

  case process.selector_receive_forever(selector) {
    Shutdown -> Nil

    ShutdownAndWait(reply) -> {
      process.send(reply, Nil)
      Nil
    }

    Drained(reply) -> {
      process.send(reply, Nil)
      loop(store, checks, commands, outcomes, on_finished)
    }

    Persist(check) -> {
      let result = store(check)

      // Informa o resultado da persistência.
      process.send(outcomes, result)

      // Notifica que a tentativa terminou,
      // independentemente de sucesso ou erro.
      on_finished(check.service_id)

      loop(store, checks, commands, outcomes, on_finished)
    }
  }
}

pub fn stop(commands: process.Subject(Command)) -> Nil {
  process.send(commands, Stop)
}

pub fn stop_and_wait(commands: process.Subject(Command)) -> Result(Nil, Nil) {
  let reply = process.new_subject()

  process.send(commands, StopAndWait(reply))

  process.receive(reply, within: 1000)
}

// Used by the consumer as a message barrier after it has emitted its checks.
pub fn drain(commands: process.Subject(Command), reply: process.Subject(Nil)) -> Nil {
  process.send(commands, Drain(reply))
}
