import gleam/option.{type Option}
import gleam/result
import gleam/uri.{type Uri}
import lustre/effect.{type Effect}
import modem
import user.{type User}

/// Represents the shared model state between all pages. Contains the
/// current URL, the current user, and the CSRF header value.
pub type Shared {
  Shared(current_url: Uri, user: user.Status, csrf_token: String)
}

pub type InitError {
  CSRFTokenNotFound
}

@external(javascript, "./csrf.mjs", "get_csrf_token")
fn get_csrf_token() -> String

pub fn new(url: Uri) -> Result(Shared, InitError) {
  use csrf_token <- result.try(case get_csrf_token() {
    "" -> Error(CSRFTokenNotFound)
    token -> Ok(token)
  })
  Ok(Shared(current_url: url, user: user.Unknown, csrf_token:))
}

/// Checks whether a the user is authenticated, redirecting if they aren't.
pub fn check_authenticated(shared: Shared) -> Effect(msg) {
  case shared.user {
    user.Unknown | user.Authenticated(_) -> effect.none()
    user.Unauthenticated -> modem.push("/login", option.None, option.None)
  }
}

/// Checks whether a the user is unauthenticated, redirecting if they **are**
/// authenticated.
pub fn check_unauthenticated(shared: Shared) -> Effect(msg) {
  case shared.user {
    user.Unknown | user.Unauthenticated -> effect.none()
    user.Authenticated(_) -> modem.push("/", option.None, option.None)
  }
}

pub fn get_user(shared: Shared) -> Option(User) {
  case shared.user {
    user.Authenticated(user) -> option.Some(user)
    user.Unauthenticated | user.Unknown -> option.None
  }
}

pub fn is_admin(shared: Shared) -> Bool {
  case get_user(shared) {
    option.Some(user) -> user.is_admin
    option.None -> False
  }
}

pub fn is_unknown(shared: Shared) -> Bool {
  case shared.user {
    user.Unknown -> True
    _ -> False
  }
}
