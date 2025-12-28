import atto
import atto/ops
import atto/text
import gleam/int
import gleam/result
import tempo/error as tempo_error
import tempo/time

fn column() {
  use <- atto.label("column")
  use digits <- atto.do(text.match("[0-9][0-9]?"))

  let assert Ok(n) = int.parse(digits)
  atto.pure(n)
}

fn colon() {
  use <- atto.label("colon")
  text.match(":")
}

fn seconds() {
  use <- atto.drop(colon())
  column()
}

fn parser() {
  use hours <- atto.do(column())
  use <- atto.drop(colon())

  use minutes <- atto.do(column())

  use seconds <- atto.do(ops.maybe(seconds()))

  atto.pure(time.new(hours, minutes, seconds |> result.unwrap(0)))
}

pub type ParseError {
  OutOfBoundsError(tempo_error.TimeOutOfBoundsError)
  ParseError(atto.ParseError(Nil, String))
}

pub fn parse(time: String) {
  case atto.run(parser(), text.new(time), Nil) {
    Ok(result) -> result |> result.map_error(OutOfBoundsError)
    Error(parse_error) -> Error(ParseError(parse_error))
  }
}
