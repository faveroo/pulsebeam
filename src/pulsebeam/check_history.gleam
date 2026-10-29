import gleam/list
import gleam/option.{type Option, None, Some}
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
