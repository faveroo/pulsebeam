import gleam/string

pub type Visibility {
  Community
  Private
}

pub type ServiceError {
  InvalidName
  InvalidUrl
  InvalidExpectedStatus
  InvalidIntervalSeconds
}

pub opaque type Service {
  Service(
    name: String,
    url: String,
    expected_status: Int,
    interval_seconds: Int,
    enabled: Bool,
    visibility: Visibility,
  )
}

pub fn new(
  name: String,
  url: String,
  expected_status: Int,
  interval_seconds: Int,
  visibility: Visibility,
) -> Result(Service, ServiceError) {
  let name = string.trim(name)
  let url = string.trim(url)
  let valid_url =
    string.starts_with(url, "http://") || string.starts_with(url, "https://")

  case
    name == "",
    interval_seconds <= 0,
    expected_status < 100 || expected_status > 599,
    !valid_url
  {
    True, _, _, _ -> Error(InvalidName)
    _, True, _, _ -> Error(InvalidIntervalSeconds)
    _, _, True, _ -> Error(InvalidExpectedStatus)
    _, _, _, True -> Error(InvalidUrl)
    False, False, False, False ->
      Ok(Service(name, url, expected_status, interval_seconds, True, visibility))
  }
}

pub fn name(service: Service) -> String {
  service.name
}

pub fn url(service: Service) -> String {
  service.url
}

pub fn expected_status(service: Service) -> Int {
  service.expected_status
}

pub fn interval_seconds(service: Service) -> Int {
  service.interval_seconds
}

pub fn is_enabled(service: Service) -> Bool {
  service.enabled
}

pub fn visibility(service: Service) -> Visibility {
  service.visibility
}

pub fn disable(service: Service) -> Service {
  case service.enabled {
    True -> Service(..service, enabled: False)
    False -> service
  }
}

pub fn enable(service: Service) -> Service {
  case service.enabled {
    True -> service
    False -> Service(..service, enabled: True)
  }
}
