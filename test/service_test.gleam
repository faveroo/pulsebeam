import pulsebeam/service

pub fn create_valid_service_test() {
  let result =
    service.new("GitHub", "https://github.com", 200, 60, service.Community)

  let assert Ok(created_service) = result

  assert service.name(created_service) == "GitHub"
  assert service.url(created_service) == "https://github.com"
  assert service.expected_status(created_service) == 200
  assert service.interval_seconds(created_service) == 60
  assert service.is_enabled(created_service) == True
  assert service.visibility(created_service) == service.Community
}

pub fn reject_empty_name_test() {
  let result = service.new("", "https://github.com", 200, 60, service.Community)

  assert result == Error(service.InvalidName)
}

pub fn reject_blank_name_test() {
  let result =
    service.new("   ", "https://github.com", 200, 60, service.Community)

  assert result == Error(service.InvalidName)
}

pub fn reject_zero_interval_test() {
  let result =
    service.new("GitHub", "https://github.com", 200, 0, service.Community)

  assert result == Error(service.InvalidIntervalSeconds)
}

pub fn reject_negative_interval_test() {
  let result =
    service.new("GitHub", "https://github.com", 200, -10, service.Community)

  assert result == Error(service.InvalidIntervalSeconds)
}

pub fn reject_status_below_100_test() {
  let result =
    service.new("GitHub", "https://github.com", 99, 60, service.Community)

  assert result == Error(service.InvalidExpectedStatus)
}

pub fn reject_status_above_599_test() {
  let result =
    service.new("GitHub", "https://github.com", 600, 60, service.Community)

  assert result == Error(service.InvalidExpectedStatus)
}

pub fn accepts_status_100_test() {
  let result =
    service.new("Example", "https://example.com", 100, 60, service.Community)

  let assert Ok(created_service) = result

  assert service.expected_status(created_service) == 100
}

pub fn accepts_status_599_test() {
  let result =
    service.new("Example", "https://example.com", 599, 60, service.Community)

  let assert Ok(created_service) = result

  assert service.expected_status(created_service) == 599
}

pub fn reject_invalid_url_test() {
  let result = service.new("GitHub", "github.com", 200, 60, service.Community)

  assert result == Error(service.InvalidUrl)
}

pub fn reject_non_http_url_test() {
  let result =
    service.new("Example", "ftp://example.com", 200, 60, service.Community)

  assert result == Error(service.InvalidUrl)
}

pub fn accepts_http_url_test() {
  let result =
    service.new("Example", "http://example.com", 200, 60, service.Community)

  let assert Ok(_) = result
}

pub fn accepts_https_url_test() {
  let result =
    service.new("Example", "https://example.com", 200, 60, service.Community)

  let assert Ok(_) = result
}

pub fn new_service_starts_enabled_test() {
  let assert Ok(created_service) =
    service.new("GitHub", "https://github.com", 200, 60, service.Community)

  assert service.is_enabled(created_service) == True
}

pub fn disable_service_test() {
  let assert Ok(created_service) =
    service.new("GitHub", "https://github.com", 200, 60, service.Community)

  let disabled_service = service.disable(created_service)

  assert service.is_enabled(disabled_service) == False
}

pub fn enable_service_test() {
  let assert Ok(created_service) =
    service.new("GitHub", "https://github.com", 200, 60, service.Community)

  let disabled_service = service.disable(created_service)
  let enabled_service = service.enable(disabled_service)

  assert service.is_enabled(enabled_service) == True
}

pub fn disabling_disabled_service_keeps_it_disabled_test() {
  let assert Ok(created_service) =
    service.new("GitHub", "https://github.com", 200, 60, service.Community)

  let disabled_once = service.disable(created_service)
  let disabled_twice = service.disable(disabled_once)

  assert service.is_enabled(disabled_twice) == False
}

pub fn enabling_enabled_service_keeps_it_enabled_test() {
  let assert Ok(created_service) =
    service.new("GitHub", "https://github.com", 200, 60, service.Community)

  let enabled_service = service.enable(created_service)

  assert service.is_enabled(enabled_service) == True
}
