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
  enabled: Bool,
  visibility: Visibility,
) -> Result(Service, ServiceError) {
    let name: String = string.trim(name)

    case 
        name == "",
        interval_seconds <= 0,
        expected_status < 100 || expected_status > 599,
        string.starts_with(url, "http://") || string.starts_with(url, "https://") == False
    {
        True, _, _, _ -> Error(InvalidName)
        _, True, _, _ -> Error(InvalidIntervalSeconds)
        _, _, True, _ -> Error(InvalidExpectedStatus)
        _, _, _, True -> Error(InvalidUrl)
        False, False, False, False -> Ok(Service(
            name,
            url,
            expected_status,
            interval_seconds,
            enabled,
            visibility
        ))
    }
}
