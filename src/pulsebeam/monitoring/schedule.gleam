import pulsebeam/service

pub type CheckState {
  Idle
  InFlight
}

pub fn on_tick(state: CheckState) -> #(CheckState, Bool) {
  case state {
    Idle -> #(InFlight, True)
    InFlight -> #(InFlight, False)
  }
}

pub fn on_check_finished(_state: CheckState) -> CheckState {
  Idle
}

pub fn first_due_ms(now_ms: Int) -> Int {
  now_ms
}

pub fn is_due(now_ms: Int, due_ms: Int) -> Bool {
  now_ms >= due_ms
}

pub fn next_due_ms(
  previous_due_ms: Int,
  now_ms: Int,
  monitored_service: service.Service,
) -> Int {
  let interval_ms = service.interval_seconds(monitored_service) * 1000

  case now_ms < previous_due_ms {
    True -> previous_due_ms

    False -> {
      let elapsed_ms = now_ms - previous_due_ms

      let interval_passed = elapsed_ms / interval_ms + 1

      previous_due_ms + interval_passed * interval_ms
    }
  }
}
