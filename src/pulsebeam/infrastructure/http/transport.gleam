import gleam/http/request
import gleam/httpc
import pulsebeam/monitoring/ports
import pulsebeam/service_check

pub fn new() -> ports.HttpTransport {
  ports.HttpTransport(get: get)
}

fn get(url: String) -> Result(Int, service_check.ServiceCheckError) {
  case request.to(url) {
    Error(_) -> Error(service_check.InvalidRequest)

    Ok(req) -> {
      case httpc.send(req) {
        Ok(response) -> Ok(response.status)

        Error(httpc.ResponseTimeout) -> Error(service_check.Timeout)

        Error(httpc.FailedToConnect(_, _)) ->
          Error(service_check.ConnectionFailed)

        Error(httpc.InvalidUtf8Response) -> Error(service_check.InvalidResponse)
      }
    }
  }
}
