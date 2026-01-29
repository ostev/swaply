import gleam/http
import gleam/http/request
import gleam/json.{type Json}
import gleam/result
import lustre/effect.{type Effect}
import rsvp

pub fn send(
  body body: Json,
  to relative_url: String,
  with method: http.Method,
  handler handler: rsvp.Handler(a),
) -> Result(Effect(a), Nil) {
  use uri <- result.try(rsvp.parse_relative_uri(relative_url))
  use request <- result.try(request.from_uri(uri))

  Ok(rsvp.send(
    request
      |> request.set_method(method)
      |> request.set_body(json.to_string(body))
      |> request.set_header("content-type", "application/json"),
    handler,
  ))
}
