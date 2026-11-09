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
