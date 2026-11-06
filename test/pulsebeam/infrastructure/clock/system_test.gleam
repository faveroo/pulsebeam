import gleam/time/timestamp
import pulsebeam/infrastructure/clock/system

pub fn clock_provides_wall_and_monotonic_time_test() {
  let clock = system.new()

  let #(seconds, _) =
    clock.now()
    |> timestamp.to_unix_seconds_and_nanoseconds

  assert seconds > 0

  let before = clock.monotonic_ms()
  let after = clock.monotonic_ms()

  assert after >= before
}
