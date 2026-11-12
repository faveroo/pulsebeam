import gleam/erlang/process
import gleam/option.{type Option, None, Some}
import pulsebeam/monitoring/scheduler
import pulsebeam/service

pub opaque type Relay {
  Relay(messages: process.Subject(Message))
}

type Message {
  Bind(process.Subject(scheduler.Command))
  Finished(service.ServiceId)
  Stop(process.Subject(Nil))
}

pub fn start(expected_service_id: service.ServiceId) -> Result(Relay, Nil) {
  let started = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      let messages = process.new_subject()

      process.send(started, Relay(messages))

      loop(messages, expected_service_id, None, False)
    })

  process.receive(started, within: 1000)
}

fn loop(
  messages: process.Subject(Message),
  expected_service_id: service.ServiceId,
  scheduler_commands: Option(process.Subject(scheduler.Command)),
  pending: Bool,
) -> Nil {
  case process.receive_forever(messages) {
    Bind(commands) -> {
      // Se uma conclusão chegou antes do Bind,
      // encaminha a confirmação agora.
      case pending {
        True -> scheduler.check_finished(commands)
        False -> Nil
      }

      loop(messages, expected_service_id, Some(commands), False)
    }

    Finished(service_id) -> {
      case service_id == expected_service_id {
        True ->
          case scheduler_commands {
            Some(commands) -> {
              scheduler.check_finished(commands)

              loop(messages, expected_service_id, Some(commands), False)
            }

            None -> loop(messages, expected_service_id, None, True)
          }

        False ->
          loop(messages, expected_service_id, scheduler_commands, pending)
      }
    }

    Stop(reply) -> {
      process.send(reply, Nil)
      Nil
    }
  }
}

pub fn bind(relay: Relay, commands: process.Subject(scheduler.Command)) -> Nil {
  process.send(relay.messages, Bind(commands))
}

pub fn finished(relay: Relay, service_id: service.ServiceId) -> Nil {
  process.send(relay.messages, Finished(service_id))
}

pub fn stop_and_wait(relay: Relay) -> Result(Nil, Nil) {
  let reply = process.new_subject()

  process.send(relay.messages, Stop(reply))

  process.receive(reply, within: 1000)
}

// Allows the application to monitor unexpected relay termination.
pub fn owner_pid(relay: Relay) -> Result(process.Pid, Nil) {
  process.subject_owner(relay.messages)
}
