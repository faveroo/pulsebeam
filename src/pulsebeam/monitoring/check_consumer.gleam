import gleam/erlang/process
import gleam/option.{None, Some}
import pulsebeam/monitoring/dispatcher
import pulsebeam/monitoring/ports
import pulsebeam/service
import pulsebeam/service_check

pub opaque type Command {
  Stop
  StopAndWait(process.Subject(Nil))
}

type Message {
  CheckRequested(service.ServiceId)
  Shutdown
  ShutdownAndWait(process.Subject(Nil))
}

pub fn start(
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
  results: process.Subject(service_check.ServiceCheck),
) -> Result(
  #(process.Subject(service.ServiceId), process.Subject(Command)),
  Nil,
) {
  let started = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      let events = process.new_subject()
      let commands = process.new_subject()

      process.send(started, #(events, commands))

      loop(monitored_service, transport, clock, events, commands, results)
    })

  process.receive(started, within: 1000)
}

fn loop(
  monitored_service: service.Service,
  transport: ports.HttpTransport,
  clock: ports.Clock,
  events: process.Subject(service.ServiceId),
  commands: process.Subject(Command),
  results: process.Subject(service_check.ServiceCheck),
) -> Nil {
  let selector =
    process.new_selector()
    |> process.select_map(events, CheckRequested)
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
    CheckRequested(requested_id) -> {
      case dispatcher.run(requested_id, monitored_service, transport, clock) {
        Some(check) -> process.send(results, check)
        None -> Nil
      }

      loop(monitored_service, transport, clock, events, commands, results)
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
