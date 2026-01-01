import api
import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/option.{type Option}
import gleam/result
import gleam/uri
import lustre/effect.{type Effect}
import pages/auth
import rsvp

const api_prefix = api.prefix <> "/user"

pub type User {
  User(
    name: String,
    email: String,
    id: String,
    is_admin: Bool,
    is_logged_in: Bool,
  )
}

pub type Status {
  Unknown
  Authenticated(User)
  Unauthenticated
}

fn decoder() -> decode.Decoder(User) {
  use is_logged_in <- decode.field("is_logged_in", decode.bool)

  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use id <- decode.field("id", decode.string)
  use is_admin <- decode.field("is_admin", decode.bool)

  decode.success(User(name:, email:, id:, is_admin:, is_logged_in:))
}

pub fn get_current_user(
  handler: fn(Result(User, rsvp.Error)) -> msg,
) -> Effect(msg) {
  let url = api_prefix <> "/current"

  rsvp.get(url, rsvp.expect_json(decoder(), fn(response) { handler(response) }))
}

pub fn list_all(
  with_email email_filter: Option(String),
  page page: Int,
  handler handler: fn(Result(List(User), rsvp.Error)) -> msg,
) -> Effect(msg) {
  rsvp.get(
    api_prefix
      <> "?"
      <> uri.query_to_string([
      #("p", int.to_string(page)),
      ..case email_filter {
        option.Some(email) -> [#("email", email)]
        option.None -> []
      }
    ]),
    rsvp.expect_json(decode.list(of: decoder()), handler),
  )
}
