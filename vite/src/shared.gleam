import gleam/option.{type Option}
import gleam/uri.{type Uri}
import lustre/effect
import modem
import pages/auth/user.{type User}

pub type Shared {
  Shared(current_url: Uri, user: UserStatus)
}

pub type UserStatus {
  Unknown
  Authenticated(User)
  Unauthenticated
}

pub fn check_authentication(shared: Shared) {
  case shared.user {
    Unknown | Authenticated(_) -> effect.none()
    Unauthenticated -> modem.push("/login", option.None, option.None)
  }
}

pub fn get_user(shared: Shared) -> Option(User) {
  case shared.user {
    Authenticated(user) -> option.Some(user)
    Unauthenticated | Unknown -> option.None
  }
}
