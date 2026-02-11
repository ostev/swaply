import gleam/dynamic/decode
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option}
import gleam/result
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

pub type Form {
  Form(email: String, name: String, password: String)
}

pub type Model {
  Model(origin: Uri, form: Form, error: Option(rsvp.Error))
}

pub fn init(origin: Uri) -> #(Model, Effect(msg)) {
  #(
    Model(
      origin:,
      form: Form(email: "", name: "", password: ""),
      error: option.None,
    ),
    effect.none(),
  )
}

pub type Msg {
  SignUpResponseReceived(Result(SignUpResponse, rsvp.Error))
  UpdatedEmail(String)
  UpdatedName(String)
  UpdatedPassword(String)
  SubmitForm
}

pub type SignUpResponse {
  Success
  InvalidPassword
  InvalidEmail
  EmailAlreadyUsed
}

fn sign_up_response_decoder() -> decode.Decoder(SignUpResponse) {
  use variant <- decode.field("result", decode.string)
  case variant {
    "success" -> decode.success(Success)
    "invalid_password" -> decode.success(InvalidPassword)
    "invalid_email" -> decode.success(InvalidEmail)
    "email_already_used" -> decode.success(EmailAlreadyUsed)
    _ -> decode.failure(InvalidPassword, "LoginResponse")
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SignUpResponseReceived(Ok(_)) -> #(
      model,
      modem.push(model.origin.path, model.origin.query, model.origin.fragment),
    )
    SignUpResponseReceived(Error(error)) -> #(
      Model(..model, error: option.Some(error)),
      effect.none(),
    )

    UpdatedEmail(new_email) -> #(
      Model(..model, form: Form(..model.form, email: new_email)),
      effect.none(),
    )
    UpdatedName(new_name) -> #(
      Model(..model, form: Form(..model.form, name: new_name)),
      effect.none(),
    )
    UpdatedPassword(new_password) -> #(
      Model(..model, form: Form(..model.form, password: new_password)),
      effect.none(),
    )

    SubmitForm -> {
      #(model, signup(model.form))
    }
  }
}

pub fn signup(form: Form) {
  let url = auth.api_prefix <> "/signup"
  let body =
    json.object([
      #("email", json.string(form.email)),
      #("name", json.string(form.name)),
      #("password", json.string(form.password)),
    ])

  rsvp.post(
    url,
    body,
    rsvp.expect_json(sign_up_response_decoder(), SignUpResponseReceived),
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
      ui.h2(css.class([css.margin_bottom(length.rem(2.0))]), "Sign up"),

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
            type_: "text",
            label: "First name",
            name: "name",
            value: option.Some(model.form.name),
            on_input: UpdatedName,
            is_valid: string.length(model.form.name) > 0,
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

          ui.submit(ui.Regular, "Sign up"),
        ],
      ),

      case model.error {
        option.Some(error) ->
          ui.panel(ui.ErrorPanel, True, case error {
            rsvp.HttpError(response) -> {
              let parsed_status =
                json.parse(
                  from: response.body,
                  using: sign_up_response_decoder(),
                )

              case response.status, parsed_status {
                422, Ok(status) ->
                  case status {
                    InvalidEmail ->
                      "The email you've provided doesn't actually exist."
                    EmailAlreadyUsed ->
                      "The email you've provided already has an account associated with it"
                    InvalidPassword ->
                      "The password you've entered is invalid. Make sure it contains at least 8 characters."
                    Success -> "Error signing up. Please try again."
                  }
                _, _ -> "Error signing up. Please try again."
              }
            }
            _ -> "Error signing up. Please try again."
          })
        option.None -> element.none()
      },
    ],
  )
}
