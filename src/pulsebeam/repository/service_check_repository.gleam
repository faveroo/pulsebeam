import gleam/time/timestamp.{type Timestamp}
import pulsebeam/repository/persistence_error.{type PersistenceError}
import pulsebeam/service.{type ServiceId}
import pulsebeam/service_check.{type ServiceCheck}

pub type ServiceCheckRepository {
  ServiceCheckRepository(
    store: fn(ServiceCheck) -> Result(Nil, PersistenceError),
    for_service: fn(ServiceId) -> Result(List(ServiceCheck), PersistenceError),
    between: fn(ServiceId, Timestamp, Timestamp) ->
      Result(List(ServiceCheck), PersistenceError),
  )
}
