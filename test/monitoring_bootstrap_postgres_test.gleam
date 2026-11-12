import gleam/list
import pog
import pulsebeam/infrastructure/postgres/service_repository
import pulsebeam/monitoring/bootstrap
import pulsebeam/service
import support/postgres as test_postgres

pub fn bootstrap_loads_enabled_services_from_postgres_test() {
  let database = test_postgres.database()

  let assert Ok(enabled) =
    service.new(
      "Bootstrap Enabled Test",
      "https://enabled.example.com",
      200,
      60,
      service.Private,
    )

  let assert Ok(second) =
    service.new(
      "Bootstrap Disabled Test",
      "https://disabled.example.com",
      200,
      30,
      service.Private,
    )

  let disabled = service.disable(second)

  // Cadastra os dois serviços no PostgreSQL.
  assert service_repository.insert(database, enabled) == Ok(Nil)
  assert service_repository.insert(database, disabled) == Ok(Nil)

  // Carrega os serviços habilitados do banco.
  let assert Ok(loaded) = bootstrap.load_enabled_from_database(database)

  // O serviço habilitado deve estar presente.
  assert list.any(loaded, fn(monitored_service) {
    service.id(monitored_service) == service.id(enabled)
  })

  // O serviço desabilitado não deve estar presente.
  assert !list.any(loaded, fn(monitored_service) {
    service.id(monitored_service) == service.id(disabled)
  })

  // Remove somente os serviços criados pelo teste.
  let enabled_id =
    enabled
    |> service.id
    |> service.service_id_to_string

  let disabled_id =
    disabled
    |> service.id
    |> service.service_id_to_string

  let assert Ok(_) =
    pog.query(
      "DELETE FROM services
       WHERE id = $1::uuid OR id = $2::uuid",
    )
    |> pog.parameter(pog.text(enabled_id))
    |> pog.parameter(pog.text(disabled_id))
    |> pog.execute(database)
}
