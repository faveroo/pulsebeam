import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/ports
import pulsebeam/monitoring/runtime
import pulsebeam/repository/persistence_error
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

pub fn runtime_finishes_pending_check_before_stopping_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Graceful Runtime Test",
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

  let saved = process.new_subject()
  let outcomes = process.new_subject()

  let store = fn(check) {
    process.send(saved, check)
    Ok(Nil)
  }

  let assert Ok(running) =
    runtime.start(monitored_service, transport, clock, store, outcomes)

  // Solicita a parada imediatamente.
  // O primeiro check ainda deve ser preservado.
  assert runtime.stop_and_wait(running) == Ok(Nil)

  let assert Ok(saved_check) = process.receive(saved, within: 1000)

  assert saved_check.service_id == service.id(monitored_service)
  assert saved_check.status == service_check.Up
  assert saved_check.outcome == service_check.HttpResponse(200)
  assert saved_check.latency_ms == Some(0)

  let assert Ok(store_result) = process.receive(outcomes, within: 1000)

  assert store_result == Ok(Nil)
}

pub fn runtime_schedules_again_after_storage_failure_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Retry Scheduling Test",
      "https://example.com",
      200,
      1,
      service.Private,
    )

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let outcomes = process.new_subject()

  // Toda tentativa de gravação falha.
  let store = fn(_) { Error(persistence_error.QueryFailed) }

  let assert Ok(running) =
    runtime.start(monitored_service, transport, clock, store, outcomes)

  // Primeira verificação: imediata.
  let assert Ok(first) = process.receive(outcomes, within: 1000)

  assert first == Error(persistence_error.QueryFailed)

  // Segunda verificação: próximo intervalo.
  // O scheduler precisa ter recebido CheckFinished.
  let assert Ok(second) = process.receive(outcomes, within: 2500)

  assert second == Error(persistence_error.QueryFailed)

  assert runtime.stop_and_wait(running) == Ok(Nil)
}

pub fn runtime_does_not_accumulate_checks_during_slow_storage_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Slow Storage Test",
      "https://example.com",
      200,
      1,
      service.Private,
    )

  let http_calls = process.new_subject()
  let store_started = process.new_subject()
  let outcomes = process.new_subject()

  // Registra cada requisição HTTP executada.
  let transport =
    ports.HttpTransport(get: fn(_) {
      process.send(http_calls, Nil)
      Ok(200)
    })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  // Simula uma gravação bloqueada.
  // O próprio persister cria o canal de liberação.
  let store = fn(_) {
    let release = process.new_subject()

    process.send(store_started, release)

    case process.receive(release, within: 5000) {
      Ok(Nil) -> Ok(Nil)
      Error(Nil) -> Error(persistence_error.QueryFailed)
    }
  }

  let assert Ok(running) =
    runtime.start(monitored_service, transport, clock, store, outcomes)

  // Primeira verificação HTTP.
  let assert Ok(Nil) = process.receive(http_calls, within: 1000)

  // A primeira gravação começou e está bloqueada.
  let assert Ok(first_release) = process.receive(store_started, within: 1000)

  // Mesmo após outro intervalo, não deve
  // acontecer uma segunda chamada HTTP.
  assert process.receive(http_calls, within: 1200) == Error(Nil)

  // Libera a primeira gravação.
  process.send(first_release, Nil)

  let assert Ok(Ok(Nil)) = process.receive(outcomes, within: 1000)

  // Após CheckFinished, o próximo Tick
  // deve produzir outra verificação.
  let assert Ok(Nil) = process.receive(http_calls, within: 2500)

  // Libera também a segunda gravação.
  let assert Ok(second_release) = process.receive(store_started, within: 1000)

  process.send(second_release, Nil)

  let assert Ok(Ok(Nil)) = process.receive(outcomes, within: 1000)

  assert runtime.stop_and_wait(running) == Ok(Nil)
}

pub fn runtime_does_not_start_disabled_service_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Disabled Runtime Test",
      "https://example.com",
      200,
      1,
      service.Private,
    )

  let disabled_service = service.disable(monitored_service)

  assert service.is_enabled(disabled_service) == False

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let outcomes = process.new_subject()
  let store = fn(_) { Ok(Nil) }

  let assert Error(Nil) =
    runtime.start(disabled_service, transport, clock, store, outcomes)
}

pub fn slow_service_does_not_block_another_service_test() {
  let assert Ok(slow_service) =
    service.new(
      "Slow Service",
      "https://slow.example.com",
      200,
      1,
      service.Private,
    )

  let assert Ok(fast_service) =
    service.new(
      "Fast Service",
      "https://fast.example.com",
      200,
      1,
      service.Private,
    )

  let transport = ports.HttpTransport(get: fn(_) { Ok(200) })

  let clock =
    ports.Clock(
      now: fn() { timestamp.from_unix_seconds(1_700_000_000) },
      monotonic_ms: fn() { 1000 },
    )

  let slow_started = process.new_subject()
  let slow_outcomes = process.new_subject()
  let fast_outcomes = process.new_subject()

  // A persistência do serviço A fica bloqueada.
  let slow_store = fn(_) {
    let release = process.new_subject()
    process.send(slow_started, release)

    case process.receive(release, within: 5000) {
      Ok(Nil) -> Ok(Nil)
      Error(Nil) -> Error(persistence_error.QueryFailed)
    }
  }

  // A persistência do serviço B é imediata.
  let fast_store = fn(_) { Ok(Nil) }

  let assert Ok(slow_runtime) =
    runtime.start(slow_service, transport, clock, slow_store, slow_outcomes)

  // Confirma que A começou a persistir
  // e está aguardando liberação.
  let assert Ok(release_slow) = process.receive(slow_started, within: 1000)

  let assert Ok(fast_runtime) =
    runtime.start(fast_service, transport, clock, fast_store, fast_outcomes)

  // B executa sua primeira verificação.
  let assert Ok(Ok(Nil)) = process.receive(fast_outcomes, within: 1000)

  // B também executa a segunda verificação,
  // mesmo enquanto A continua bloqueado.
  let assert Ok(Ok(Nil)) = process.receive(fast_outcomes, within: 2000)

  // Encerra B antes de liberar A.
  assert runtime.stop_and_wait(fast_runtime) == Ok(Nil)

  // Agora liberamos a gravação de A.
  process.send(release_slow, Nil)

  let assert Ok(Ok(Nil)) = process.receive(slow_outcomes, within: 1000)

  assert runtime.stop_and_wait(slow_runtime) == Ok(Nil)
}
