import gleam/erlang/process
import pulsebeam/monitoring/completion_relay
import pulsebeam/monitoring/scheduler
import pulsebeam/service

pub fn completion_before_binding_is_forwarded_test() {
  let assert Ok(monitored_service) =
    service.new("Relay Test", "https://example.com", 200, 1, service.Private)

  let notifications = process.new_subject()

  let assert Ok(relay) = completion_relay.start(service.id(monitored_service))

  let assert Ok(commands) =
    scheduler.start_with_completion(monitored_service, notifications)

  // Primeira verificação imediata.
  let assert Ok(first) = process.receive(notifications, within: 1000)

  assert first == service.id(monitored_service)

  // Simula uma conclusão que chegou antes
  // de o relay conhecer o scheduler.
  completion_relay.finished(relay, service.id(monitored_service))

  completion_relay.bind(relay, commands)

  // Após a confirmação, o próximo Tick
  // poderá emitir outra verificação.
  let assert Ok(second) = process.receive(notifications, within: 1500)

  assert second == service.id(monitored_service)

  assert scheduler.stop_and_wait(commands) == Ok(Nil)
  assert completion_relay.stop_and_wait(relay) == Ok(Nil)
}
