import gleam/option
import gleam/time/duration
import gleam/time/timestamp
import pulsebeam/service
import pulsebeam/service_check
import pulsebeam/uptime

fn create_service() -> service.Service {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  monitored_service
}

fn create_check(
  service_id: service.ServiceId,
  checked_at: timestamp.Timestamp,
  status: service_check.CheckStatus,
) -> service_check.ServiceCheck {
  service_check.ServiceCheck(
    service_id: service_id,
    checked_at: checked_at,
    latency_ms: option.None,
    outcome: service_check.HttpResponse(200),
    status: status,
  )
}

// ---------------------------------------------------------
// Basic uptime calculation
// ---------------------------------------------------------

pub fn empty_history_returns_not_available_test() {
  let result = uptime.calculate_uptime([])

  assert result == uptime.NotAvailable
}

pub fn all_checks_up_returns_100_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let checks = [
    create_check(service_id, timestamp.from_unix_seconds(100), service_check.Up),
  ]

  let result = uptime.calculate_uptime(checks)

  assert result == uptime.Available(100.0)
}

pub fn all_checks_down_returns_zero_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let checks = [
    create_check(
      service_id,
      timestamp.from_unix_seconds(100),
      service_check.Down,
    ),
  ]

  let result = uptime.calculate_uptime(checks)

  assert result == uptime.Available(0.0)
}

pub fn one_up_and_one_down_returns_50_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let checks = [
    create_check(service_id, timestamp.from_unix_seconds(100), service_check.Up),
    create_check(
      service_id,
      timestamp.from_unix_seconds(200),
      service_check.Down,
    ),
  ]

  let result = uptime.calculate_uptime(checks)

  assert result == uptime.Available(50.0)
}

pub fn three_up_and_one_down_returns_75_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let checks = [
    create_check(service_id, timestamp.from_unix_seconds(100), service_check.Up),
    create_check(service_id, timestamp.from_unix_seconds(200), service_check.Up),
    create_check(service_id, timestamp.from_unix_seconds(300), service_check.Up),
    create_check(
      service_id,
      timestamp.from_unix_seconds(400),
      service_check.Down,
    ),
  ]

  let result = uptime.calculate_uptime(checks)

  assert result == uptime.Available(75.0)
}

pub fn two_up_and_two_down_returns_50_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let checks = [
    create_check(service_id, timestamp.from_unix_seconds(100), service_check.Up),
    create_check(service_id, timestamp.from_unix_seconds(200), service_check.Up),
    create_check(
      service_id,
      timestamp.from_unix_seconds(300),
      service_check.Down,
    ),
    create_check(
      service_id,
      timestamp.from_unix_seconds(400),
      service_check.Down,
    ),
  ]

  let result = uptime.calculate_uptime(checks)

  assert result == uptime.Available(50.0)
}

pub fn one_up_and_three_down_returns_25_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let checks = [
    create_check(service_id, timestamp.from_unix_seconds(100), service_check.Up),
    create_check(
      service_id,
      timestamp.from_unix_seconds(200),
      service_check.Down,
    ),
    create_check(
      service_id,
      timestamp.from_unix_seconds(300),
      service_check.Down,
    ),
    create_check(
      service_id,
      timestamp.from_unix_seconds(400),
      service_check.Down,
    ),
  ]

  let result = uptime.calculate_uptime(checks)

  assert result == uptime.Available(25.0)
}

// ---------------------------------------------------------
// Uptime by period
// ---------------------------------------------------------

pub fn period_with_no_history_returns_not_available_test() {
  let now = timestamp.from_unix_seconds(3_000_000)

  let result = uptime.calculate_for_period([], uptime.Last24Hours, now)

  assert result == uptime.NotAvailable
}

pub fn insufficient_24_hour_history_returns_not_available_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let six_hours_ago = timestamp.subtract(now, duration.hours(6))

  let checks = [
    create_check(service_id, six_hours_ago, service_check.Up),
    create_check(service_id, now, service_check.Up),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last24Hours, now)

  assert result == uptime.NotAvailable
}

pub fn insufficient_history_does_not_assume_100_percent_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let one_hour_ago = timestamp.subtract(now, duration.hours(1))

  let checks = [
    create_check(service_id, one_hour_ago, service_check.Up),
    create_check(service_id, now, service_check.Up),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last24Hours, now)

  assert result == uptime.NotAvailable
}

pub fn complete_24_hour_history_calculates_uptime_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let period_start = timestamp.subtract(now, duration.hours(24))

  let twelve_hours_ago = timestamp.subtract(now, duration.hours(12))

  let checks = [
    create_check(service_id, period_start, service_check.Up),
    create_check(service_id, twelve_hours_ago, service_check.Down),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last24Hours, now)

  assert result == uptime.Available(50.0)
}

pub fn check_before_period_makes_history_sufficient_but_is_not_counted_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let period_start = timestamp.subtract(now, duration.hours(24))

  let before_period = timestamp.subtract(period_start, duration.hours(1))

  let twelve_hours_ago = timestamp.subtract(now, duration.hours(12))

  let checks = [
    create_check(service_id, before_period, service_check.Down),
    create_check(service_id, twelve_hours_ago, service_check.Up),
    create_check(service_id, now, service_check.Up),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last24Hours, now)

  assert result == uptime.Available(100.0)
}

pub fn check_after_now_is_not_counted_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let period_start = timestamp.subtract(now, duration.hours(24))

  let future = timestamp.add(now, duration.hours(1))

  let checks = [
    create_check(service_id, period_start, service_check.Up),
    create_check(service_id, now, service_check.Up),
    create_check(service_id, future, service_check.Down),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last24Hours, now)

  assert result == uptime.Available(100.0)
}

pub fn complete_7_day_history_calculates_uptime_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let period_start = timestamp.subtract(now, duration.hours(24 * 7))

  let three_days_ago = timestamp.subtract(now, duration.hours(24 * 3))

  let one_day_ago = timestamp.subtract(now, duration.hours(24))

  let checks = [
    create_check(service_id, period_start, service_check.Up),
    create_check(service_id, three_days_ago, service_check.Up),
    create_check(service_id, one_day_ago, service_check.Up),
    create_check(service_id, now, service_check.Down),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last7Days, now)

  assert result == uptime.Available(75.0)
}

pub fn insufficient_7_day_history_returns_not_available_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let three_days_ago = timestamp.subtract(now, duration.hours(24 * 3))

  let checks = [
    create_check(service_id, three_days_ago, service_check.Up),
    create_check(service_id, now, service_check.Down),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last7Days, now)

  assert result == uptime.NotAvailable
}

pub fn complete_30_day_history_calculates_uptime_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let period_start = timestamp.subtract(now, duration.hours(24 * 30))

  let twenty_days_ago = timestamp.subtract(now, duration.hours(24 * 20))

  let ten_days_ago = timestamp.subtract(now, duration.hours(24 * 10))

  let checks = [
    create_check(service_id, period_start, service_check.Up),
    create_check(service_id, twenty_days_ago, service_check.Up),
    create_check(service_id, ten_days_ago, service_check.Down),
    create_check(service_id, now, service_check.Down),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last30Days, now)

  assert result == uptime.Available(50.0)
}

pub fn insufficient_30_day_history_returns_not_available_test() {
  let monitored_service = create_service()
  let service_id = service.id(monitored_service)

  let now = timestamp.from_unix_seconds(3_000_000)

  let ten_days_ago = timestamp.subtract(now, duration.hours(24 * 10))

  let checks = [
    create_check(service_id, ten_days_ago, service_check.Up),
    create_check(service_id, now, service_check.Up),
  ]

  let result = uptime.calculate_for_period(checks, uptime.Last30Days, now)

  assert result == uptime.NotAvailable
}
