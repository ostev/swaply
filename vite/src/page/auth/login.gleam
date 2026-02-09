import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/string
import gleam/uri.{type Uri}
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/event as e
import modem
import page/auth
import rsvp
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import ui
import ui/layout
import ui/styles

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
  IncorrectCredentials
  InvalidEmail
}

fn login_response_decoder() -> decode.Decoder(LoginResponse) {
  use variant <- decode.field("result", decode.string)
  case variant {
    "success" -> decode.success(Success)
    "incorrect_credentials" -> decode.success(IncorrectCredentials)
    "invalid_email" -> decode.success(InvalidEmail)
    _ -> decode.failure(IncorrectCredentials, "LoginResponse")
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LoginResponseReceived(Ok(_)) -> #(
      model,
      modem.push(model.origin.path, model.origin.query, model.origin.fragment),
    )
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

fn login(form: Form) -> Effect(Msg) {
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
  let spacing = css.class([css.margin_bottom(length.px(14))])
  h.div(
    css.class([
      css.compose(layout.column(layout.Center)),
      css.margin_top(length.rem(3.0)),
    ]),
    [],
    [
      ui.h2(css.class([css.margin_bottom(length.rem(2.0))]), "Login"),
      h.form(
        css.class([
          css.compose(styles.card()),
          css.max_width(length.rem(20.0)),
          css.width(length.percent(100)),
        ]),
        [e.on_submit(fn(_) { SubmitForm })],
        [
          ui.input(
            spacing,
            type_: "text",
            label: "Email",
            name: "email",
            value: option.Some(model.form.email),
            on_input: UpdatedEmail,
            is_valid: model.form.email |> string.contains("@"),
          ),
          ui.input(
            spacing,
            type_: "password",
            label: "Password",
            name: "password",
            value: option.Some(model.form.password),
            on_input: UpdatedPassword,
            is_valid: string.length(model.form.password) >= 8,
          ),
          ui.submit(ui.Regular, "Login"),

          case model.error {
            option.Some(error) -> {
              ui.error_panel(True, case error {
                rsvp.HttpError(response) -> {
                  case response.status {
                    401 | 422 -> "Incorrect email or password"
                    _ -> "Error logging in. Please try again."
                  }
                }
                _ -> "Error logging in. Please try again."
              })
            }
            option.None -> element.none()
          },
        ],
      ),
    ],
  )
}
