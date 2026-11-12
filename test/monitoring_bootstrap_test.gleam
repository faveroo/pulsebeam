import gleam/erlang/process
import pulsebeam/monitoring/bootstrap
import pulsebeam/repository/persistence_error
import pulsebeam/service

pub fn bootstrap_selects_only_enabled_services_test() {
  let assert Ok(first) =
    service.new(
      "Enabled Service",
      "https://enabled.example.com",
      200,
      60,
      service.Private,
    )

  let assert Ok(second) =
    service.new(
      "Disabled Service",
      "https://disabled.example.com",
      200,
      30,
      service.Private,
    )

  let disabled = service.disable(second)

  let selected = bootstrap.enabled_services([first, disabled])

  assert selected == [first]
}

pub fn bootstrap_loads_only_enabled_services_test() {
  let assert Ok(first) =
    service.new(
      "Enabled Service",
      "https://enabled.example.com",
      200,
      60,
      service.Private,
    )

  let assert Ok(second) =
    service.new(
      "Disabled Service",
      "https://disabled.example.com",
      200,
      30,
      service.Private,
    )

  let disabled = service.disable(second)

  // Simula o resultado de service_repository.list().
  let load = fn() { Ok([first, disabled]) }

  let result = bootstrap.load_enabled_services(load)

  assert result == Ok([first])
}

pub fn bootstrap_starts_only_enabled_services_test() {
  let assert Ok(first) =
    service.new("Service A", "https://a.example.com", 200, 60, service.Private)

  let assert Ok(second) =
    service.new("Service B", "https://b.example.com", 200, 30, service.Private)

  let assert Ok(third) =
    service.new("Service C", "https://c.example.com", 200, 15, service.Private)

  let disabled = service.disable(second)

  // Simula a inicialização de um runtime.
  // Por enquanto, apenas devolve o ID do serviço.
  let start = fn(monitored_service) { Ok(service.id(monitored_service)) }

  let stop = fn(_) { Nil }

  let assert Ok(started_ids) =
    bootstrap.start_enabled_services([first, disabled, third], start, stop)

  assert started_ids
    == [
      service.id(first),
      service.id(third),
    ]
}

pub fn bootstrap_stops_started_services_after_failure_test() {
  let assert Ok(first) =
    service.new("Service A", "https://a.example.com", 200, 60, service.Private)

  let assert Ok(second) =
    service.new("Service B", "https://b.example.com", 200, 30, service.Private)

  let assert Ok(third) =
    service.new("Service C", "https://c.example.com", 200, 15, service.Private)

  // Usado pelo teste para observar
  // quais serviços foram encerrados.
  let stopped = process.new_subject()

  // Simula uma falha ao iniciar C.
  let start = fn(monitored_service) {
    case service.name(monitored_service) {
      "Service C" -> Error(Nil)
      _ -> Ok(service.id(monitored_service))
    }
  }

  // Registra cada chamada de stop().
  let stop = fn(service_id) { process.send(stopped, service_id) }

  let result =
    bootstrap.start_enabled_services([first, second, third], start, stop)

  // A inicialização completa deve falhar.
  assert result == Error(Nil)

  // B deve ser encerrado primeiro.
  let assert Ok(first_stopped) = process.receive(stopped, within: 1000)

  assert first_stopped == service.id(second)

  // Depois A.
  let assert Ok(second_stopped) = process.receive(stopped, within: 1000)

  assert second_stopped == service.id(first)

  // Nenhum outro serviço deve ser encerrado.
  assert process.receive(stopped, within: 100) == Error(Nil)
}

pub fn bootstrap_starts_services_returned_by_loader_test() {
  let assert Ok(first) =
    service.new(
      "Enabled Service",
      "https://enabled.example.com",
      200,
      60,
      service.Private,
    )

  let assert Ok(second) =
    service.new(
      "Disabled Service",
      "https://disabled.example.com",
      200,
      30,
      service.Private,
    )

  let disabled = service.disable(second)

  let load = fn() { Ok([first, disabled]) }

  let start = fn(monitored_service) { Ok(service.id(monitored_service)) }

  let stop = fn(_) { Nil }

  let result = bootstrap.start_loaded_services(load, start, stop)

  assert result == Ok([service.id(first)])
}

pub fn bootstrap_does_not_start_services_when_load_fails_test() {
  let started = process.new_subject()

  // Simula uma falha ao consultar o PostgreSQL.
  let load = fn() { Error(persistence_error.ConnectionFailed) }

  // Registra qualquer tentativa de iniciar um serviço.
  let start = fn(monitored_service) {
    process.send(started, service.id(monitored_service))
    Ok(service.id(monitored_service))
  }

  let stop = fn(_) { Nil }

  let result = bootstrap.start_loaded_services(load, start, stop)

  // O erro original deve ser preservado.
  assert result == Error(persistence_error.ConnectionFailed)

  // Nenhum serviço deve ter sido iniciado.
  assert process.receive(started, within: 100) == Error(Nil)
}
