import pulsebeam/monitoring/schedule
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
