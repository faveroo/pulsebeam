import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import pulsebeam/infrastructure/postgres/connection
import pulsebeam/monitoring/bootstrap
import pulsebeam/repository/persistence_error

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

          consume_outcomes(outcomes)
        }
      }
    }
  }
}

fn consume_outcomes(
  outcomes: process.Subject(Result(Nil, persistence_error.PersistenceError)),
) -> Nil {
  let outcome = process.receive_forever(outcomes)

  case outcome {
    Ok(Nil) -> io.println("Verificação persistida com sucesso.")

    Error(_) -> io.println("Falha ao persistir uma verificação.")
  }

  consume_outcomes(outcomes)
}
