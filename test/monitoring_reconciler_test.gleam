import pulsebeam/monitoring/reconciler
import pulsebeam/service

pub fn disabled_active_service_is_planned_for_stop_test() {
  // Um serviço em execução foi desabilitado na configuração persistida.
  let assert Ok(monitored_service) =
    service.new(
      "Example",
      "https://example.com",
      200,
      60,
      service.Private,
    )

  let active_ids = [service.id(monitored_service)]
  let persisted_services = [service.disable(monitored_service)]

  let actions = reconciler.plan(active_ids, persisted_services)

  assert actions == [reconciler.Stop(service.id(monitored_service))]
}
