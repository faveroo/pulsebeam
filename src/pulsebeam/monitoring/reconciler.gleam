import gleam/list
import pulsebeam/service

/// Ação necessária para aproximar os runtimes ativos do estado persistido.
pub type Action {
  Stop(service.ServiceId)
}

/// Planeja paradas de serviços desabilitados que ainda possuem runtime ativo.
///
/// Esta função é pura: não acessa o banco e não envia mensagens a processos.
pub fn plan(
  active_service_ids: List(service.ServiceId),
  persisted_services: List(service.Service),
) -> List(Action) {
  persisted_services
  |> list.filter(fn(monitored_service) {
    !service.is_enabled(monitored_service)
    && list.contains(active_service_ids, service.id(monitored_service))
  })
  |> list.map(fn(monitored_service) {
    Stop(service.id(monitored_service))
  })
}
