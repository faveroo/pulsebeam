import gleam/string
import gleam/uri

pub type Visibility {
  Community
  Private
}

pub type ServiceError {
  EmptyName
  InvalidUrl
  InvalidExpectedStatus
  InvalidInterval
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
  name name: String,
  url url: String,
  expected_status expected_status: Int,
  interval_seconds interval_seconds: Int,
  visibility visibility: Visibility,
) -> Result(Service, ServiceError) {
  let clean_name = string.trim(name)

  case
    clean_name == "",
    valid_http_url(url),
    valid_http_status(expected_status),
    interval_seconds > 0
  {
    True, _, _, _ -> Error(EmptyName)
    _, False, _, _ -> Error(InvalidUrl)
    _, _, False, _ -> Error(InvalidExpectedStatus)
    _, _, _, False -> Error(InvalidInterval)
    False, True, True, True ->
      Ok(Service(
        name: clean_name,
        url: url,
        expected_status: expected_status,
        interval_seconds: interval_seconds,
        enabled: True,
        visibility: visibility,
      ))
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

fn valid_http_status(status: Int) -> Bool {
  status >= 100 && status <= 599
}

fn valid_http_url(value: String) -> Bool {
  case uri.parse(value) {
    Error(_) -> False
    Ok(parsed) ->
      case uri.origin(parsed) {
        Ok(_) -> True
        Error(_) -> False
      }
  }
}
