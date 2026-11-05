import gleam/time/timestamp
import pulsebeam/monitoring/ports

pub fn new() -> ports.Clock {
  ports.Clock(now: timestamp.system_time, monotonic_ms: monotonic_ms)
}

@external(erlang, "pulsebeam_clock_ffi", "monotonic_ms")
fn monotonic_ms() -> Int
