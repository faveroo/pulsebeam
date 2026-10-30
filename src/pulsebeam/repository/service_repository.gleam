import gleam/option.{type Option}
import pulsebeam/repository/persistence_error.{
  type PersistenceError
}
import pulsebeam/service.{type Service, type ServiceId}

pub type ServiceRepostiory {
  ServiceRepostiory(
    insert: fn(Service) -> Result(Nil, PersistenceError),
    update: fn(Service) -> Result(Nil, PersistenceError),
    find_by_id: fn(ServiceId) -> Result(Option(Service), PersistenceError),
    list: fn() -> Result(List(Service), PersistenceError),
  )
}


