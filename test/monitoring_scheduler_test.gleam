import gleam/erlang/process
import pulsebeam/monitoring/schedule
import pulsebeam/monitoring/scheduler
import pulsebeam/service

fn monitored_service() -> service.Service {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  monitored_service
}

pub fn next_due_normal_interval_test() {
  let next = schedule.next_due_ms(1000, 1000, monitored_service())

  assert next == 61_000
}

pub fn next_due_skips_missed_intervals_test() {
  let next = schedule.next_due_ms(1000, 185_000, monitored_service())

  assert next == 241_000
}

pub fn next_due_preserves_future_schedule_test() {
  let next = schedule.next_due_ms(61_000, 30_000, monitored_service())

  assert next == 61_000
}

pub fn scheduler_emits_initial_check_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Initial Service",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let notifications = process.new_subject()

  let assert Ok(commands) = scheduler.start(monitored_service, notifications)

  let received = process.receive(notifications, within: 1000)

  assert received == Ok(service.id(monitored_service))

  scheduler.stop(commands)
}

pub fn scheduler_emits_periodic_checks_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Periodic Service",
      "https://example.com",
      200,
      1,
      service.Private,
    )

  let notifications = process.new_subject()

  let assert Ok(commands) = scheduler.start(monitored_service, notifications)

  // Primeira verificação: imediata.
  let first = process.receive(notifications, within: 500)

  assert first == Ok(service.id(monitored_service))

  // Segunda verificação: após aproximadamente 1 segundo.
  let second = process.receive(notifications, within: 1500)

  assert second == Ok(service.id(monitored_service))

  scheduler.stop(commands)
}

pub fn scheduler_stops_after_acknowledgement_test() {
  let assert Ok(monitored_service) =
    service.new("Stop Test", "https://example.com", 200, 1, service.Private)

  let notifications = process.new_subject()

  let assert Ok(commands) = scheduler.start(monitored_service, notifications)

  // Primeira verificação imediata.
  let assert Ok(_) = process.receive(notifications, within: 1000)

  // Solicita parada e aguarda confirmação.
  assert scheduler.stop_and_wait(commands) == Ok(Nil)

  // Depois da confirmação, não deve haver
  // outro Tick no próximo intervalo.
  assert process.receive(notifications, within: 1200) == Error(Nil)
}

pub fn idle_scheduler_allows_check_test() {
  let #(state, should_dispatch) = schedule.on_tick(schedule.Idle)

  assert should_dispatch == True
  assert state == schedule.InFlight
}

pub fn busy_scheduler_skips_check_test() {
  let #(state, should_dispatch) = schedule.on_tick(schedule.InFlight)

  assert should_dispatch == False
  assert state == schedule.InFlight
}

pub fn finished_check_allows_next_execution_test() {
  let #(running, first_dispatch) = schedule.on_tick(schedule.Idle)

  assert first_dispatch == True

  let ready = schedule.on_check_finished(running)

  let #(next_state, second_dispatch) = schedule.on_tick(ready)

  assert second_dispatch == True
  assert next_state == schedule.InFlight
}

pub fn scheduler_waits_for_check_completion_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Backpressure Test",
      "https://example.com",
      200,
      1,
      service.Private,
    )

  let notifications = process.new_subject()

  let assert Ok(commands) =
    scheduler.start_with_completion(monitored_service, notifications)

  // Primeira verificação: imediata.
  let assert Ok(first) = process.receive(notifications, within: 1000)

  assert first == service.id(monitored_service)

  // Espera passar o próximo Tick.
  // O scheduler ainda está InFlight,
  // então não deve emitir outro check.
  assert process.receive(notifications, within: 1200) == Error(Nil)

  // Informa que a primeira verificação terminou.
  scheduler.check_finished(commands)

  // Agora o próximo Tick pode emitir outro check.
  let assert Ok(second) = process.receive(notifications, within: 1500)

  assert second == service.id(monitored_service)

  assert scheduler.stop_and_wait(commands) == Ok(Nil)
}
