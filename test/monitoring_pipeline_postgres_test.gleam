import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pog
import pulsebeam/infrastructure/postgres/service_check_repository
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/monitoring/check_consumer
import pulsebeam/monitoring/check_persister
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/scheduler
import pulsebeam/service
import pulsebeam/service_check
import support/postgres as test_postgres

pub fn scheduled_check_is_persisted_in_postgres_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new(
      "PostgreSQL Pipeline Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  // A chave estrangeira exige que o serviço exista.
  let assert Ok(Nil) = service_repository.insert(database, monitored_service)

  // HTTP falso: nenhuma chamada à internet.
  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let outcomes = process.new_subject()

  // Agora o armazenamento usa o PostgreSQL real.
  let store = fn(check) { service_check_repository.store(database, check) }

  let assert Ok(#(checks, persister_commands)) =
    check_persister.start(store, outcomes)

  let assert Ok(#(events, consumer_commands)) =
    check_consumer.start(monitored_service, transport, clock, checks)

  let assert Ok(scheduler_commands) = scheduler.start(monitored_service, events)

  // Aguarda a confirmação da gravação.
  let assert Ok(store_result) = process.receive(outcomes, within: 2000)

  assert store_result == Ok(Nil)

  // Consulta o registro realmente armazenado.
  let assert Ok([persisted]) =
    service_check_repository.for_service(
      database,
      service.id(monitored_service),
    )

  assert persisted.service_id == service.id(monitored_service)
  assert persisted.status == service_check.Up
  assert persisted.outcome == service_check.HttpResponse(200)
  assert persisted.latency_ms == Some(0)
  assert persisted.checked_at == timestamp.from_unix_seconds(1_700_000_000)

  scheduler.stop(scheduler_commands)
  check_consumer.stop(consumer_commands)
  check_persister.stop(persister_commands)

  // Limpeza dos registros criados pelo teste.
  let service_id =
    service.id(monitored_service)
    |> service.service_id_to_string

  let assert Ok(_) =
    pog.query("DELETE FROM service_checks WHERE service_id = $1::uuid")
    |> pog.parameter(pog.text(service_id))
    |> pog.execute(database)

  let assert Ok(_) =
    pog.query("DELETE FROM services WHERE id = $1::uuid")
    |> pog.parameter(pog.text(service_id))
    |> pog.execute(database)
}
