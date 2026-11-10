import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/check_consumer
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/scheduler
import pulsebeam/service
import pulsebeam/service_check

pub fn scheduler_event_produces_service_check_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Scheduled Service",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let results = process.new_subject()

  let assert Ok(#(events, consumer_commands)) =
    check_consumer.start(monitored_service, transport, clock, results)

  let assert Ok(scheduler_commands) = scheduler.start(monitored_service, events)

  let assert Ok(check) = process.receive(results, within: 1000)

  assert check.service_id == service.id(monitored_service)
  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)
  assert check.latency_ms == Some(0)

  scheduler.stop(scheduler_commands)
  check_consumer.stop(consumer_commands)
}

pub fn consumer_finishes_queued_checks_before_stopping_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Shutdown Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let results = process.new_subject()

  let assert Ok(#(events, commands)) =
    check_consumer.start(monitored_service, transport, clock, results)

  // Envia duas solicitações antes da parada.
  process.send(events, service.id(monitored_service))
  process.send(events, service.id(monitored_service))

  // Aguarda a confirmação do consumer.
  assert check_consumer.stop_and_wait(commands) == Ok(Nil)

  // Ambas as verificações devem ter sido concluídas.
  let assert Ok(first) = process.receive(results, within: 1000)

  let assert Ok(second) = process.receive(results, within: 1000)

  assert first.status == service_check.Up
  assert second.status == service_check.Up

  assert first.service_id == service.id(monitored_service)
  assert second.service_id == service.id(monitored_service)
}
