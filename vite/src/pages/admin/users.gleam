import gleam/dynamic/decode
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
import user.{type User}

pub type Model {
  Model(page: Int, users: Option(Result(List(user.User), rsvp.Error)))
}

pub fn init() -> #(Model, Effect(Msg)) {
  let page = 0

  #(
    Model(page:, users: option.None),
    user.list_all(page:, with_email: option.None, handler: UsersReceived),
  )
}

pub type Msg {
  UsersReceived(response: Result(List(user.User), rsvp.Error))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UsersReceived(response) -> #(
      Model(..model, users: option.Some(response)),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [h.h1([], [h.text("Manage users")]), h.table([], [])])
}
