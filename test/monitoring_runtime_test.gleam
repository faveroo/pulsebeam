import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/runtime
import pulsebeam/service
import pulsebeam/service_check

pub fn runtime_connects_all_components_test() {
  let assert Ok(monitored_service) =
    service.new("Runtime Test", "https://example.com", 200, 60, service.Private)

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let saved = process.new_subject()
  let outcomes = process.new_subject()

  let store = fn(check) {
    process.send(saved, check)
    Ok(Nil)
  }

  // Uma única chamada inicializa os três componentes.
  let assert Ok(running) =
    runtime.start(monitored_service, transport, clock, store, outcomes)

  let assert Ok(check) = process.receive(saved, within: 1000)

  assert check.service_id == service.id(monitored_service)
  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)
  assert check.latency_ms == Some(0)

  let assert Ok(store_result) = process.receive(outcomes, within: 1000)

  assert store_result == Ok(Nil)

  runtime.stop(running)
}
