import gleeunit
import pulsebeam/service

pub fn main() {
  gleeunit.main()
}

pub fn creates_valid_service_test() {
  let assert Ok(created) =
    service.new(
      name: "GitHub",
      url: "https://github.com",
      expected_status: 200,
      interval_seconds: 60,
      visibility: service.Community,
    )

  assert service.name(created) == "GitHub"
  assert service.url(created) == "https://github.com"
  assert service.expected_status(created) == 200
  assert service.interval_seconds(created) == 60
  assert service.is_enabled(created)
  assert service.visibility(created) == service.Community
}

pub fn trims_service_name_test() {
  let assert Ok(created) =
    service.new(
      name: "  GitHub  ",
      url: "https://github.com",
      expected_status: 200,
      interval_seconds: 60,
      visibility: service.Community,
    )

  assert service.name(created) == "GitHub"
}

pub fn rejects_empty_name_test() {
  assert Error(service.EmptyName) =
    service.new(
      name: "   ",
      url: "https://github.com",
      expected_status: 200,
      interval_seconds: 60,
      visibility: service.Community,
    )
}

pub fn rejects_non_http_url_test() {
  assert Error(service.InvalidUrl) =
    service.new(
      name: "Example",
      url: "ftp://example.com",
      expected_status: 200,
      interval_seconds: 60,
      visibility: service.Private,
    )
}

pub fn rejects_invalid_expected_status_test() {
  assert Error(service.InvalidExpectedStatus) =
    service.new(
      name: "Example",
      url: "https://example.com",
      expected_status: 700,
      interval_seconds: 60,
      visibility: service.Private,
    )
}

pub fn rejects_non_positive_interval_test() {
  assert Error(service.InvalidInterval) =
    service.new(
      name: "Example",
      url: "https://example.com",
      expected_status: 200,
      interval_seconds: 0,
      visibility: service.Private,
    )
}
