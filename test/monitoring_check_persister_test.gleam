import gleam/erlang/process
import gleam/option.{Some}
import gleam/time/timestamp
import pulsebeam/monitoring/check_persister
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
