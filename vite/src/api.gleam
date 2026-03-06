import gleam/http
import gleam/http/request
import gleam/json.{type Json}
import gleam/result
import lustre/effect.{type Effect}
import rsvp

pub const prefix = "/api/v1"

pub fn send_with_known_url(
  body body: Json,
  to relative_url: String,
  with method: http.Method,
  handler handler: rsvp.Handler(msg),
  with_token csrf_token: String,
) -> Effect(msg) {
  send(body, relative_url, method, handler, csrf_token)
  |> result.lazy_unwrap(fn() {
    panic as { "The provided URL `" <> relative_url <> "` is not valid." }
  })
}

pub fn send(
  body body: Json,
  to relative_url: String,
  with method: http.Method,
  handler handler: rsvp.Handler(msg),
  with_token csrf_token: String,
) -> Result(Effect(msg), Nil) {
  {
    use uri <- result.try(rsvp.parse_relative_uri(prefix <> relative_url))
    use request <- result.try(request.from_uri(uri))

    Ok(rsvp.send(
      request
        |> request.set_method(method)
        |> request.set_body(json.to_string(body))
        |> request.set_header("content-type", "application/json")
        |> request.set_header("X-CSRF-Token", csrf_token),
      handler,
    ))
  }
}
