import gleam/erlang/process
import pulsebeam/repository/persistence_error
import pulsebeam/service_check

pub opaque type Command {
  Stop
  StopAndWait(process.Subject(Nil))
}

type Message {
  Persist(service_check.ServiceCheck)
  Shutdown
  ShutdownAndWait(process.Subject(Nil))
}

pub fn start(
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
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

      loop(store, checks, commands, outcomes)
    })

  process.receive(started, within: 1000)
}

fn loop(
  store: fn(service_check.ServiceCheck) ->
    Result(Nil, persistence_error.PersistenceError),
  checks: process.Subject(service_check.ServiceCheck),
  commands: process.Subject(Command),
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Nil {
  let selector =
    process.new_selector()
    |> process.select_map(checks, Persist)
    |> process.select_map(commands, fn(command) {
      case command {
        Stop -> Shutdown
        StopAndWait(reply) -> ShutdownAndWait(reply)
      }
    })

  case process.selector_receive_forever(selector) {
    Shutdown -> Nil

    ShutdownAndWait(reply) -> {
      process.send(reply, Nil)
      Nil
    }

    Persist(check) -> {
      let result = store(check)

      process.send(outcomes, result)

      loop(store, checks, commands, outcomes)
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
