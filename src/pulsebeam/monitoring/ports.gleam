import gleam/time/timestamp.{type Timestamp}
import pulsebeam/service_check.{type ServiceCheckError}

pub type HttpTransport {
  HttpTransport(get: fn(String) -> Result(Int, ServiceCheckError))
}

pub type Clock {
  Clock(now: fn() -> Timestamp, monotonic_ms: fn() -> Int)
}
