import api
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/uri
import lustre/effect.{type Effect}
import rsvp
import search
import tempo

const api_root = "/user"

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
  let url = api_root <> "/current"

  api.get(url, rsvp.expect_json(decoder(), fn(response) { handler(response) }))
}

pub fn get(
  id: String,
  handler: fn(Result(User, rsvp.Error)) -> msg,
) -> Effect(msg) {
  api.get(
    api_root <> "/" <> uri.percent_encode(id),
    rsvp.expect_json(decoder(), handler),
  )
}

pub fn list_all(
  with_email email_filter: Option(String),
  page page: Int,
  at_timestamp timestamp: tempo.Instant,
  handler handler: fn(Result(search.Results(User), rsvp.Error)) -> msg,
) -> Effect(msg) {
  let results_decoder = {
    use number_of_pages <- decode.field("number_of_pages", decode.int)
    use users <- decode.field("users", decode.list(of: decoder()))

    decode.success(search.Results(values: users, number_of_pages:, timestamp:))
  }

  api.get(
    api_root
      <> "?"
      <> uri.query_to_string([
      #("p", int.to_string(page)),
      ..case email_filter {
        option.Some(email) -> [#("email", email)]
        option.None -> []
      }
    ]),
    rsvp.expect_json(results_decoder, handler),
  )
}

pub fn delete(
  id: String,
  handler: fn(Result(Nil, rsvp.Error)) -> msg,
  with_token csrf_token: String,
) -> Result(Effect(msg), Nil) {
  api.send(
    body: json.object([]),
    to: api_root <> uri.percent_encode(id),
    with: http.Delete,
    handler: rsvp.expect_ok_response(fn(response) {
      response
      |> result.replace(Nil)
      |> handler
    }),
    with_token: csrf_token,
  )
}

pub type UpdateError {
  InvalidEmail
  EmailAlreadyUsed
  RsvpError(rsvp.Error)
}

fn update_error_decoder() -> decode.Decoder(UpdateError) {
  use variant <- decode.field("result", decode.string)
  case variant {
    "invalid_email" -> decode.success(InvalidEmail)
    "email_already_used" -> decode.success(EmailAlreadyUsed)
    _ -> decode.failure(InvalidEmail, "UpdateError")
  }
}

pub fn update(
  id id: String,
  email email: Option(String),
  is_admin is_admin: Option(Bool),
  handler handler: fn(Result(User, UpdateError)) -> msg,
  with_token csrf_token: String,
) {
  let body =
    json.object(
      []
      |> list.append(case email {
        option.Some(email) -> [#("email", json.string(email))]
        option.None -> []
      })
      |> list.append(case is_admin {
        option.Some(is_admin) -> [#("is_admin", json.bool(is_admin))]
        option.None -> []
      }),
    )

  api.send(
    body:,
    to: api_root <> uri.percent_encode(id),
    with: http.Patch,
    with_token: csrf_token,
    handler: rsvp.expect_json(decoder(), fn(result) {
      case result {
        Ok(user) -> handler(Ok(user))
        Error(error) ->
          handler(
            Error(case error {
              rsvp.HttpError(response) if response.status == 422 -> {
                case
                  json.parse(from: response.body, using: update_error_decoder())
                {
                  Ok(update_error) -> update_error
                  Error(_) -> RsvpError(error)
                }
              }
              _ -> RsvpError(error)
            }),
          )
      }
    }),
  )
}
