import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import pulsebeam/infrastructure/postgres/connection
import pulsebeam/monitoring/bootstrap
import pulsebeam/monitoring/runtime
import pulsebeam/repository/persistence_error
import pulsebeam/service

type MainEvent {
  Stored(Result(Nil, persistence_error.PersistenceError))
  ComponentExited(process.Down)
}

type WatchedProcess {
  WatchedProcess(monitor: process.Monitor, service_id: service.ServiceId)
}

pub fn main() -> Nil {
  case envoy.get("PULSEBEAM_DATABASE_URL") {
    Error(_) -> io.println("PULSEBEAM_DATABASE_URL não foi configurado")

    Ok(database_url) -> {
      start_monitoring(database_url)
    }
  }
}

fn start_monitoring(database_url: String) -> Nil {
  let pool_name = process.new_name("pulsebeam_monitoring")

  case connection.start(pool_name, database_url) {
    Error(_) -> io.println("Não foi possível iniciar o PostgreSQL")

    Ok(database) -> {
      let outcomes = process.new_subject()

      case bootstrap.start_live_from_database(database, outcomes) {
        Error(_) -> {
          io.println("Falha ao iniciar o monitoramento")
        }

        Ok(runtimes) -> {
          let count = list.length(runtimes)

          io.println(
            "PulseBeam iniciado com " <> int.to_string(count) <> " serviço(s).",
          )

          let watched =
            list.flat_map(runtimes, fn(running) {
              case runtime.process_ids(running) {
                Ok(pids) ->
                  list.map(pids, fn(pid) {
                    WatchedProcess(
                      monitor: process.monitor(pid),
                      service_id: runtime.service_id(running),
                    )
                  })
                Error(_) -> {
                  io.println("Aviso: não foi possível monitorar um runtime.")
                  []
                }
              }
            })

          consume_outcomes(outcomes, watched)
        }
      }
    }
  }
}

fn consume_outcomes(
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
  watched: List(WatchedProcess),
) -> Nil {
  let selector =
    process.new_selector()
    |> process.select_map(outcomes, Stored)
    |> process.select_monitors(ComponentExited)

  case process.selector_receive_forever(selector) {
    Stored(Ok(Nil)) -> io.println("Verificação persistida com sucesso.")

    Stored(Error(_)) -> io.println("Falha ao persistir uma verificação.")

    ComponentExited(process.ProcessDown(monitor, _, _)) -> {
      case list.find(watched, fn(item) { item.monitor == monitor }) {
        Ok(item) ->
          io.println(
            "ALERTA: processo do serviço "
            <> service.service_id_to_string(item.service_id)
            <> " terminou. O monitoramento pode estar interrompido; "
            <> "reinício automático ainda não implementado.",
          )
        Error(_) -> io.println("ALERTA: processo de monitoramento terminou.")
      }
    }

    ComponentExited(process.PortDown(_, _, _)) ->
      io.println("ALERTA: porta monitorada foi encerrada.")
  }

  consume_outcomes(outcomes, watched)
}
