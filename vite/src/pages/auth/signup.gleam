import gleam/json
import pages/auth
import rsvp

pub type Form {
  Form(email: String, name: String, password: String)
}

pub fn signup(form: Form, handler) {
  let url = auth.api_prefix <> "/login"
  let body =
    json.object([
      #("email", json.string(form.email)),
      #("name", json.string(form.name)),
      #("password", json.string(form.password)),
    ])

  rsvp.post(url, body, handler)
}
