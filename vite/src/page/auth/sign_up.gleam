import api
import extra/url
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option.{type Option}
import gleam/string
import gleam/uri.{type Uri}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/event as e
import modem
import page/auth
import rsvp
import shared.{type Shared}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import ui
import ui/button
import ui/input
import ui/layout
import ui/styles
import user

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
  InvalidName
  InvalidEmail
  EmailAlreadyUsed
  PasswordIsCommon
  PasswordIsWord
}

fn sign_up_response_decoder() -> decode.Decoder(SignUpResponse) {
  use variant <- decode.field("result", decode.string)
  case variant {
    "success" -> decode.success(Success)
    "invalid_password" -> decode.success(InvalidPassword)
    "invalid_name" -> decode.success(InvalidName)
    "invalid_email" -> decode.success(InvalidEmail)
    "email_already_used" -> decode.success(EmailAlreadyUsed)
    "password_is_common" -> decode.success(PasswordIsCommon)
    "password_is_word" -> decode.success(PasswordIsWord)
    _ -> decode.failure(InvalidPassword, "LoginResponse")
  }
}

pub fn update(
  shared: Shared,
  model: Model,
  msg: Msg,
) -> #(Model, Shared, Effect(Msg)) {
  case msg {
    SignUpResponseReceived(Ok(_)) -> #(
      model,
      shared.Shared(..shared, user: user.Unknown),
      modem.push(
        url.replace_empty_with_root(model.origin.path),
        model.origin.query,
        model.origin.fragment,
      ),
    )
    SignUpResponseReceived(Error(error)) -> #(
      Model(..model, error: option.Some(error)),
      shared,
      effect.none(),
    )

    UpdatedEmail(new_email) -> #(
      Model(..model, form: Form(..model.form, email: new_email)),
      shared,
      effect.none(),
    )
    UpdatedName(new_name) -> #(
      Model(..model, form: Form(..model.form, name: new_name)),
      shared,
      effect.none(),
    )
    UpdatedPassword(new_password) -> #(
      Model(..model, form: Form(..model.form, password: new_password)),
      shared,
      effect.none(),
    )

    SubmitForm -> {
      #(model, shared, signup(model.form, with_token: shared.csrf_token))
    }
  }
}

pub fn signup(form: Form, with_token token: String) {
  let body =
    json.object([
      #("email", json.string(form.email)),
      #("name", json.string(form.name)),
      #("password", json.string(form.password)),
    ])

  api.send_with_known_url(
    body:,
    to: auth.api_root <> "/signup",
    with: http.Post,
    handler: rsvp.expect_json(
      sign_up_response_decoder(),
      SignUpResponseReceived,
    ),
    with_token: token,
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
      h.div(
        css.class([
          css.compose(layout.column(layout.Center)),
          css.max_width(length.rem(20.0)),
          css.width(length.percent(100)),
        ]),
        [],
        [
          ui.h2(css.class([css.margin_bottom(length.rem(2.0))]), "Sign up"),

          h.form(
            css.class([
              css.compose(styles.card()),
              css.width(length.percent(100)),
            ]),
            [e.on_submit(fn(_) { SubmitForm })],
            [
              input.generic(
                spacing,
                type_: "text",
                label: "Email",
                name: "email",
                value: option.Some(model.form.email),
                on_input: UpdatedEmail,
                is_valid: model.form.email |> string.contains("@"),
              ),
              input.generic(
                spacing,
                type_: "text",
                label: "First name",
                name: "name",
                value: option.Some(model.form.name),
                on_input: UpdatedName,
                is_valid: string.length(model.form.name) > 0,
              ),
              input.generic(
                spacing,
                type_: "password",
                label: "Password",
                name: "password",
                value: option.Some(model.form.password),
                on_input: UpdatedPassword,
                is_valid: string.length(model.form.password) >= 8,
              ),

              button.submit(button.Primary, "Sign up"),
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
                        InvalidName ->
                          "Please enter a name that is 2 characters or longer."
                        EmailAlreadyUsed ->
                          "The email you've provided already has an account associated with it"
                        InvalidPassword ->
                          "Your password needs to be at least 8 characters long."
                        PasswordIsCommon ->
                          "Your password is very common. Please choose a different one."
                        PasswordIsWord ->
                          "Your password is a word in the English language. Please choose a different one."
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
      ),
    ],
  )
}
