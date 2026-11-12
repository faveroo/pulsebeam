import gleam/erlang/process
import pulsebeam/infrastructure/clock/system
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/schedule
import pulsebeam/service

pub opaque type Command {
  Stop
  StopAndWait(process.Subject(Nil))
  StopAndDrain(process.Subject(Nil), fn(process.Subject(Nil)) -> Nil)
  Tick
  CheckFinished
}

pub fn start(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
) -> Result(process.Subject(Command), Nil) {
  start_with_mode(monitored_service, notifications, False)
}

pub fn start_with_completion(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
) -> Result(process.Subject(Command), Nil) {
  start_with_mode(monitored_service, notifications, True)
}

fn start_with_mode(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
  require_completion: Bool,
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

      let state = case require_completion {
        True -> schedule.InFlight
        False -> schedule.Idle
      }

      loop(
        monitored_service,
        notifications,
        commands,
        clock,
        next_due,
        state,
        require_completion,
      )
    })

  process.receive(started, within: 1000)
}

fn loop(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
  commands: process.Subject(Command),
  clock: ports.Clock,
  next_due: Int,
  state: schedule.CheckState,
  require_completion: Bool,
) -> Nil {
  let now_ms = clock.monotonic_ms()

  let delay_ms = case next_due - now_ms {
    delay if delay > 0 -> delay
    _ -> 0
  }

  let timer = process.send_after(commands, delay_ms, Tick)

  wait_for_tick(
    monitored_service,
    notifications,
    commands,
    clock,
    next_due,
    state,
    require_completion,
    timer,
  )
}

fn wait_for_tick(
  monitored_service: service.Service,
  notifications: process.Subject(service.ServiceId),
  commands: process.Subject(Command),
  clock: ports.Clock,
  next_due: Int,
  state: schedule.CheckState,
  require_completion: Bool,
  timer: process.Timer,
) -> Nil {
  case process.receive_forever(commands) {
    Stop -> {
      let _ = process.cancel_timer(timer)
      Nil
    }

    StopAndWait(reply) -> {
      let _ = process.cancel_timer(timer)
      process.send(reply, Nil)
      Nil
    }

    StopAndDrain(reply, notify_downstream) -> {
      let _ = process.cancel_timer(timer)
      // Sent from the scheduler process: ordered after all check requests.
      notify_downstream(reply)
      Nil
    }

    CheckFinished -> {
      let new_state = case require_completion {
        True -> schedule.on_check_finished(state)
        False -> state
      }

      // Mantém o mesmo timer enquanto
      // atualiza apenas o estado.
      wait_for_tick(
        monitored_service,
        notifications,
        commands,
        clock,
        next_due,
        new_state,
        require_completion,
        timer,
      )
    }

    Tick -> {
      let #(new_state, should_dispatch) = case require_completion {
        True -> schedule.on_tick(state)
        False -> #(state, True)
      }

      case should_dispatch {
        True -> process.send(notifications, service.id(monitored_service))
        False -> Nil
      }

      let next =
        schedule.next_due_ms(next_due, clock.monotonic_ms(), monitored_service)

      loop(
        monitored_service,
        notifications,
        commands,
        clock,
        next,
        new_state,
        require_completion,
      )
    }
  }
}

pub fn check_finished(commands: process.Subject(Command)) -> Nil {
  process.send(commands, CheckFinished)
}

pub fn stop(commands: process.Subject(Command)) -> Nil {
  process.send(commands, Stop)
}

pub fn stop_and_wait(commands: process.Subject(Command)) -> Result(Nil, Nil) {
  let reply = process.new_subject()

  process.send(commands, StopAndWait(reply))

  process.receive(reply, within: 1000)
}

// Waits until the consumer acknowledges a barrier sent by this scheduler.
// The barrier is ordered behind all previously dispatched check requests.
pub fn stop_and_drain(
  commands: process.Subject(Command),
  notify_downstream: fn(process.Subject(Nil)) -> Nil,
) -> Result(Nil, Nil) {
  let reply = process.new_subject()
  process.send(commands, StopAndDrain(reply, notify_downstream))
  process.receive(reply, within: 30_000)
}
