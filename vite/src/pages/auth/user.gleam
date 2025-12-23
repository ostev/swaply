import gleam/bool
import gleam/dynamic/decode
import gleam/io
import gleam/option.{type Option}
import gleam/result
import lustre/effect.{type Effect}
import pages/auth
import rsvp

pub type User {
  User(name: String, email: String, id: String)
}

fn user_status_decoder() -> decode.Decoder(Option(User)) {
  use is_logged_in <- decode.field("is_logged_in", decode.bool)

  case is_logged_in {
    True -> {
      use name <- decode.field("name", decode.string)
      use email <- decode.field("email", decode.string)
      use id <- decode.field("id", decode.string)

      decode.success(option.Some(User(name:, email:, id:)))
    }
    False -> {
      decode.success(option.None)
    }
  }
}

pub fn get_current_user(handler: fn(Option(User)) -> a) -> Effect(a) {
  let url = auth.api_prefix <> "/user"

  rsvp.get(
    url,
    rsvp.expect_json(user_status_decoder(), fn(response) {
      handler(response |> result.unwrap(option.None))
    }),
  )
}
