import gleam/int
import gleam/list
import gleam/order
import gleam/time/duration
import gleam/time/timestamp
import pulsebeam/service_check.{type ServiceCheck, Up}

pub type Uptime {
  Available(Float)
  NotAvailable
}

pub type UptimePeriod {
  Last24Hours
  Last7Days
  Last30Days
}

pub fn calculate_uptime(checks: List(ServiceCheck)) -> Uptime {
  let total = list.length(checks)

  case total {
    0 -> NotAvailable

    _ -> {
      let up = list.count(checks, fn(c) { service_check.status(c) == Up })
      let uptime = int.to_float(up) /. int.to_float(total) *. 100.0
      Available(uptime)
    }
  }
}

pub fn calculate_for_period(
  checks: List(ServiceCheck),
  period: UptimePeriod,
  now: timestamp.Timestamp,
) -> Uptime {
  let from = period_start(now, period)

  let has_enough_history =
    list.any(checks, fn(check) {
      let checked_at = service_check.checked_at(check)

      case timestamp.compare(checked_at, from) {
        order.Gt -> False
        _ -> True
      }
    })

  case has_enough_history {
    False -> NotAvailable

    True -> {
      let period_checks =
        list.filter(checks, fn(check) {
          let checked_at = service_check.checked_at(check)

          let after_or_equal_from = case timestamp.compare(checked_at, from) {
            order.Lt -> False
            _ -> True
          }

          let before_or_equal_to = case timestamp.compare(checked_at, now) {
            order.Gt -> False
            _ -> True
          }

          after_or_equal_from && before_or_equal_to
        })

      calculate_uptime(period_checks)
    }
  }
}

fn period_start(
  now: timestamp.Timestamp,
  period: UptimePeriod,
) -> timestamp.Timestamp {
  case period {
    Last24Hours -> timestamp.subtract(now, duration.hours(24))

    Last7Days -> timestamp.subtract(now, duration.hours(24 * 7))

    Last30Days -> timestamp.subtract(now, duration.hours(24 * 30))
  }
}
