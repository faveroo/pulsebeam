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
