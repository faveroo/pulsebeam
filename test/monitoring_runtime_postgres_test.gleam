import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import pog
import pulsebeam/infrastructure/postgres/service_check_repository
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/monitoring/runtime
import pulsebeam/service
import pulsebeam/service_check
import support/http_server
import support/postgres as test_postgres

fn local_url() -> String {
  let assert Ok(port) = http_server.start(200)

  "http://127.0.0.1:" <> int.to_string(port) <> "/"
}

pub fn live_runtime_persists_http_check_test() {
  let database = test_postgres.database()

  let assert Ok(monitored_service) =
    service.new("Live Runtime Test", local_url(), 200, 60, service.Private)

  // O serviço precisa existir no PostgreSQL
  // antes de armazenarmos suas verificações.
  let assert Ok(Nil) = service_repository.insert(database, monitored_service)

  let outcomes = process.new_subject()

  // Usa os adapters reais:
  // HTTP + Clock + PostgreSQL.
  let assert Ok(running) =
    runtime.start_live(monitored_service, database, outcomes)

  // Aguarda a persistência da primeira verificação.
  let assert Ok(Ok(Nil)) = process.receive(outcomes, within: 3000)

  // Consulta o histórico no PostgreSQL.
  let assert Ok([check]) =
    service_check_repository.for_service(
      database,
      service.id(monitored_service),
    )

  assert check.service_id == service.id(monitored_service)
  assert check.status == service_check.Up
  assert check.outcome == service_check.HttpResponse(200)

  let assert Some(latency) = check.latency_ms
  assert latency >= 0

  // Solicita a parada dos processos.
  runtime.stop(running)

  // Limpa os registros criados pelo teste.
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
