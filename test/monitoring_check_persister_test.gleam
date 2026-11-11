import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/check_persister
import pulsebeam/monitoring/schedule
import pulsebeam/repository/persistence_error
import pulsebeam/service
import pulsebeam/service_check

pub fn persister_stores_received_check_test() {
  let assert Ok(monitored_service) =
    service.new("Example", "https://example.com", 200, 60, service.Private)

  let check =
    service_check.from_result(
      monitored_service,
      timestamp.from_unix_seconds(1_700_000_000),
      Ok(200),
      Some(42),
    )

  let saved = process.new_subject()
  let outcomes = process.new_subject()

  // Repositório falso: registra qual check foi recebido.
  let store = fn(received_check) {
    process.send(saved, received_check)
    Ok(Nil)
  }

  let assert Ok(#(checks, commands)) = check_persister.start(store, outcomes)

  process.send(checks, check)

  let assert Ok(saved_check) = process.receive(saved, within: 1000)

  assert saved_check == check

  let assert Ok(store_result) = process.receive(outcomes, within: 1000)

  assert store_result == Ok(Nil)

  check_persister.stop(commands)
}

pub fn persister_continues_after_storage_failure_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Persistence Failure Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let first_check =
    service_check.from_result(monitored_service, checked_at, Ok(200), Some(10))

  let second_check =
    service_check.from_result(monitored_service, checked_at, Ok(503), Some(20))

  let outcomes = process.new_subject()

  // Simula uma primeira gravação com falha
  // e uma segunda gravação bem-sucedida.
  let store = fn(check: service_check.ServiceCheck) {
    case check.status {
      service_check.Up -> Error(persistence_error.QueryFailed)
      service_check.Down -> Ok(Nil)
    }
  }

  let assert Ok(#(checks, commands)) = check_persister.start(store, outcomes)

  process.send(checks, first_check)
  process.send(checks, second_check)

  let first_result = process.receive(outcomes, within: 1000)
  let second_result = process.receive(outcomes, within: 1000)

  assert first_result == Ok(Error(persistence_error.QueryFailed))
  assert second_result == Ok(Ok(Nil))

  check_persister.stop(commands)
}

pub fn persister_finishes_queued_writes_before_stopping_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Graceful Shutdown Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let first_check =
    service_check.from_result(monitored_service, checked_at, Ok(200), Some(10))

  let second_check =
    service_check.from_result(monitored_service, checked_at, Ok(503), Some(20))

  let saved = process.new_subject()
  let outcomes = process.new_subject()

  let store = fn(check) {
    process.send(saved, check)
    Ok(Nil)
  }

  let assert Ok(#(checks, commands)) = check_persister.start(store, outcomes)

  // Duas gravações antes da solicitação de parada.
  process.send(checks, first_check)
  process.send(checks, second_check)

  // Aguarda a confirmação do persister.
  assert check_persister.stop_and_wait(commands) == Ok(Nil)

  // Confirma que ambas foram processadas.
  let assert Ok(saved_first) = process.receive(saved, within: 1000)

  let assert Ok(saved_second) = process.receive(saved, within: 1000)

  assert saved_first == first_check
  assert saved_second == second_check

  // Confirma que ambas as operações tiveram sucesso.
  let assert Ok(first_result) = process.receive(outcomes, within: 1000)

  let assert Ok(second_result) = process.receive(outcomes, within: 1000)

  assert first_result == Ok(Nil)
  assert second_result == Ok(Nil)
}

pub fn idle_scheduler_allows_check_test() {
  let #(state, should_dispatch) = schedule.on_tick(schedule.Idle)

  assert should_dispatch == True
  assert state == schedule.InFlight
}

pub fn busy_scheduler_skips_check_test() {
  let #(state, should_dispatch) = schedule.on_tick(schedule.InFlight)

  assert should_dispatch == False
  assert state == schedule.InFlight
}

pub fn finished_check_allows_next_execution_test() {
  let #(running, first_dispatch) = schedule.on_tick(schedule.Idle)

  assert first_dispatch == True

  let ready = schedule.on_check_finished(running)

  let #(next_state, second_dispatch) = schedule.on_tick(ready)

  assert second_dispatch == True
  assert next_state == schedule.InFlight
}

pub fn persister_notifies_completion_after_success_and_failure_test() {
  let assert Ok(monitored_service) =
    service.new(
      "Completion Test",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let checked_at = timestamp.from_unix_seconds(1_700_000_000)

  let first_check =
    service_check.from_result(monitored_service, checked_at, Ok(200), Some(10))

  let second_check =
    service_check.from_result(monitored_service, checked_at, Ok(503), Some(20))

  let outcomes = process.new_subject()
  let completions = process.new_subject()

  let store = fn(check: service_check.ServiceCheck) {
    case check.status {
      service_check.Up -> Error(persistence_error.QueryFailed)

      service_check.Down -> Ok(Nil)
    }
  }

  let on_finished = fn(service_id) { process.send(completions, service_id) }

  let assert Ok(#(checks, commands)) =
    check_persister.start_with_completion(store, outcomes, on_finished)

  // Primeira gravação: falha.
  process.send(checks, first_check)

  let assert Ok(first_result) = process.receive(outcomes, within: 1000)

  let assert Ok(first_completion) = process.receive(completions, within: 1000)

  assert first_result == Error(persistence_error.QueryFailed)
  assert first_completion == service.id(monitored_service)

  // Segunda gravação: sucesso.
  process.send(checks, second_check)

  let assert Ok(second_result) = process.receive(outcomes, within: 1000)

  let assert Ok(second_completion) = process.receive(completions, within: 1000)

  assert second_result == Ok(Nil)
  assert second_completion == service.id(monitored_service)

  assert check_persister.stop_and_wait(commands) == Ok(Nil)
}
