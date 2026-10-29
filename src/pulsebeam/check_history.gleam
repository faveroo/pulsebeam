import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/time/timestamp
import pulsebeam/service.{type ServiceId}
import pulsebeam/service_check.{type ServiceCheck}

pub opaque type CheckHistory {
  CheckHistory(checks: List(ServiceCheck))
}

pub fn new() -> CheckHistory {
  CheckHistory(checks: [])
}

pub fn store(history: CheckHistory, check: ServiceCheck) -> CheckHistory {
  CheckHistory(checks: [check, ..history.checks])
}

pub fn size(history: CheckHistory) -> Int {
  list.length(history.checks)
}

pub fn latest(history: CheckHistory) -> Option(ServiceCheck) {
  case history.checks {
    [] -> None
    [first, ..] -> Some(first)
  }
}

pub fn for_service(
  history: CheckHistory,
  service_id: ServiceId,
) -> List(ServiceCheck) {
  history.checks
  |> list.filter(fn(check) { service_check.service_id(check) == service_id })
}

pub fn for_service_between(
  history: CheckHistory,
  service_id: ServiceId,
  from: timestamp.Timestamp,
  to: timestamp.Timestamp,
) -> List(ServiceCheck) {
  let service_history = for_service(history, service_id)

  service_history
  |> list.filter(fn(check) {
    let checked_at = service_check.checked_at(check)

    let after_or_equal_from = case timestamp.compare(checked_at, from) {
      order.Lt -> False
      _ -> True
    }

    let before_or_equal_to = case timestamp.compare(checked_at, to) {
      order.Gt -> False
      _ -> True
    }

    after_or_equal_from && before_or_equal_to
  })
}
