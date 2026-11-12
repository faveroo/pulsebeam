import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/check_consumer
import pulsebeam/monitoring/check_persister
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/scheduler
import pulsebeam/service
import pulsebeam/service_check

pub fn scheduled_check_reaches_persistence_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Scheduled Service",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  // Dependências falsas para evitar HTTP real.
  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  // Canal para observar o que foi armazenado.
  let saved = process.new_subject()
  let outcomes = process.new_subject()

  let store = fn(check) {
    process.send(saved, check)
    Ok(Nil)
  }

  // 1. Inicia o consumidor de persistência.
  let assert Ok(#(checks, persister_commands)) =
    check_persister.start(store, outcomes)

  // 2. Conecta o consumidor de checks ao persister.
  let assert Ok(#(events, consumer_commands)) =
    check_consumer.start(monitored_service, transport, clock, checks)

  // 3. Conecta o scheduler ao consumidor.
  let assert Ok(scheduler_commands) = scheduler.start(monitored_service, events)

  // 4. Aguarda o resultado chegar ao repositório falso.
  let assert Ok(saved_check) = process.receive(saved, within: 1000)

  assert saved_check.service_id == service.id(monitored_service)
  assert saved_check.status == service_check.Up
  assert saved_check.outcome == service_check.HttpResponse(200)
  assert saved_check.latency_ms == Some(0)

  // 5. Verifica se a persistência informou sucesso.
  let assert Ok(store_result) = process.receive(outcomes, within: 1000)

  assert store_result == Ok(Nil)

  // 6. Solicita a parada dos processos.
  scheduler.stop(scheduler_commands)
  check_consumer.stop(consumer_commands)
  check_persister.stop(persister_commands)
}
