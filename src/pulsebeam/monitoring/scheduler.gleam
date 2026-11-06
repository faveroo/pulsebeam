import gleam/erlang/process
import pulsebeam/infrastructure/clock/system
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/schedule
import pulsebeam/service

pub opaque type Command {
  Stop
  Tick
}

pub fn start(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
) -> Result(process.Subject(Command), Nil) {
  let started = process.new_subject()

  let _pid =
    process.spawn_unlinked(fn() {
      let commands = process.new_subject()
      let clock = system.new()

      process.send(started, commands)

      let first_due = schedule.first_due_ms(clock.monotonic_ms())

      // Primeira verificação imediata.
      process.send(notifications, service.id(monitored_service))

      let next_due =
        schedule.next_due_ms(first_due, clock.monotonic_ms(), monitored_service)

      loop(monitored_service, notifications, commands, clock, next_due)
    })

  process.receive(started, within: 1000)
}

fn loop(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
  commands: process.Subject(Command),
  clock: ports.Clock,
  next_due: Int,
) -> Nil {
  let now_ms = clock.monotonic_ms()

  let delay_ms = case next_due - now_ms {
    delay if delay > 0 -> delay
    _ -> 0
  }

  let timer = process.send_after(commands, delay_ms, Tick)

  case process.receive_forever(commands) {
    Stop -> {
      let _ = process.cancel_timer(timer)
      Nil
    }

    Tick -> {
      process.send(notifications, service.id(monitored_service))

      let next =
        schedule.next_due_ms(next_due, clock.monotonic_ms(), monitored_service)

      loop(monitored_service, notifications, commands, clock, next)
    }
  }
}

pub fn stop(commands: process.Subject(Command)) -> Nil {
  process.send(commands, Stop)
}
