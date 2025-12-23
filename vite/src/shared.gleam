import gleam/option.{type Option}
import gleam/uri.{type Uri}
import pages/auth/user.{type User}

pub type Shared {
  Shared(current_url: Uri, user: Option(User))
}
