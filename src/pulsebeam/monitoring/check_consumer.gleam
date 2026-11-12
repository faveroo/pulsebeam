import gleam/erlang/process
import gleam/option.{None, Some}
import pulsebeam/monitoring/dispatcher
import pulsebeam/monitoring/ports
import pulsebeam/service
import pulsebeam/service_check

pub opaque type Command {
  Stop
  StopAndWait(process.Subject(Nil))
  Drain(process.Subject(Nil))
  StopAndDrain(process.Subject(Nil), fn(process.Subject(Nil)) -> Nil)
}

type Message {
  CheckRequested(service.ServiceId)
  Shutdown
  ShutdownAndWait(process.Subject(Nil))
  Drained(process.Subject(Nil))
  ShutdownAndDrain(process.Subject(Nil), fn(process.Subject(Nil)) -> Nil)
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
        Drain(reply) -> Drained(reply)
        StopAndDrain(reply, notify_downstream) ->
          ShutdownAndDrain(reply, notify_downstream)
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
      loop(monitored_service, transport, clock, events, commands, results)
    }

    ShutdownAndDrain(reply, notify_downstream) -> {
      // The consumer has processed all earlier scheduler events; send a
      // barrier after all previously emitted ServiceChecks.
      notify_downstream(reply)
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

// Called by the scheduler process so the acknowledgement is ordered after
// every preceding CheckRequested sent by that same scheduler.
pub fn drain(
  commands: process.Subject(Command),
  reply: process.Subject(Nil),
) -> Nil {
  process.send(commands, Drain(reply))
}

// Called by runtime; sends the downstream barrier from the consumer process.
pub fn stop_and_drain(
  commands: process.Subject(Command),
  notify_downstream: fn(process.Subject(Nil)) -> Nil,
) -> Result(Nil, Nil) {
  let reply = process.new_subject()
  process.send(commands, StopAndDrain(reply, notify_downstream))
  process.receive(reply, within: 30_000)
}
