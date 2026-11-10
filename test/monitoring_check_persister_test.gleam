import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/check_persister
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
