import gleam/dynamic/decode
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option}
import gleam/string
import gleam/uri.{type Uri}
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import modem
import pages/auth
import rsvp
import ui

pub type Model {
  Model(origin: Uri, form: Form, error: Option(rsvp.Error))
}

pub type Form {
  Form(email: String, password: String)
}

pub fn init(origin: Uri) -> #(Model, Effect(msg)) {
  #(
    Model(origin:, form: Form(email: "", password: ""), error: option.None),
    effect.none(),
  )
}

pub type Msg {
  LoginResponseReceived(Result(LoginResponse, rsvp.Error))
  UpdatedEmail(String)
  UpdatedPassword(String)
  SubmitForm
}

pub type LoginResponse {
  Success
  InvalidPassword
  InvalidEmail
}

fn login_response_decoder() -> decode.Decoder(LoginResponse) {
  use variant <- decode.then(decode.string)
  case variant {
    "success" -> decode.success(Success)
    "invalid_password" -> decode.success(InvalidPassword)
    "invalid_email" -> decode.success(InvalidEmail)
    _ -> decode.failure(InvalidPassword, "LoginResponse")
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LoginResponseReceived(Ok(_)) -> #(model, modem.load(model.origin))
    LoginResponseReceived(Error(error)) -> #(
      Model(..model, error: option.Some(error)),
      effect.none(),
    )

    UpdatedEmail(new_email) -> #(
      Model(..model, form: Form(..model.form, email: new_email)),
      effect.none(),
    )
    UpdatedPassword(new_password) -> #(
      Model(..model, form: Form(..model.form, password: new_password)),
      effect.none(),
    )

    SubmitForm -> {
      #(model, login(model.form))
    }
  }
}

pub fn login(form: Form) -> Effect(Msg) {
  let url = auth.api_prefix <> "/login"
  let body =
    json.object([
      #("email", json.string(form.email)),
      #("password", json.string(form.password)),
    ])

  rsvp.post(
    url,
    body,
    rsvp.expect_json(login_response_decoder(), LoginResponseReceived),
  )
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.form([e.on_submit(fn(_) { SubmitForm })], [
      ui.input(
        type_: "text",
        label: "Email",
        name: "email",
        value: model.form.email,
        on_input: UpdatedEmail,
        is_valid: model.form.email |> string.contains("@"),
      ),
      ui.input(
        type_: "password",
        label: "Password",
        name: "password",
        value: model.form.password,
        on_input: UpdatedPassword,
        is_valid: string.length(model.form.password) >= 8,
      ),
      h.button([a.type_("submit")], [h.text("Login")]),
    ]),
    h.div([], case model.error {
      option.Some(error) -> {
        case error {
          rsvp.HttpError(response) -> {
            case response.status {
              401 | 422 -> [h.p([], [h.text("Incorrect email or password")])]
              _ -> [h.p([], [h.text("Error logging in. Please try again.")])]
            }
          }
          _ -> [h.p([], [h.text("Error logging in. Please try again.")])]
        }
      }
      option.None -> []
    }),
  ])
}
