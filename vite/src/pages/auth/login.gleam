import gleam/json
import pages/auth
import rsvp

pub type Form {
  Form(email: String, password: String)
}

pub fn login(form: Form, handler) {
  let url = auth.api_prefix <> "/login"
  let body =
    json.object([
      #("email", json.string(form.email)),
      #("password", json.string(form.password)),
    ])

  rsvp.post(url, body, handler)
}
