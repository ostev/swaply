import gleam/option.{type Option}
import gleam/uri.{type Uri}
import lustre/effect
import modem
import user.{type User}

pub type Shared {
  Shared(current_url: Uri, user: user.Status)
}

pub fn check_authentication(shared: Shared) {
  case shared.user {
    user.Unknown | user.Authenticated(_) -> effect.none()
    user.Unauthenticated -> modem.push("/login", option.None, option.None)
  }
}

pub fn get_user(shared: Shared) -> Option(User) {
  case shared.user {
    user.Authenticated(user) -> option.Some(user)
    user.Unauthenticated | user.Unknown -> option.None
  }
}
