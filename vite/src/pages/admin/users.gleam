import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
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
import shared.{type Shared}
import ui
import ui/table
import user.{type User}

pub type Model {
  Model(
    page: Int,
    email_filter: Option(String),
    users: Option(Result(List(user.User), rsvp.Error)),
  )
}

pub fn init(shared: Shared) -> #(Model, Effect(Msg)) {
  let page = 0

  #(
    Model(page:, email_filter: option.None, users: option.None),
    effect.batch([
      shared.check_authentication(shared),
      user.list_all(page:, with_email: option.None, handler: UsersReceived),
    ]),
  )
}

pub type Msg {
  UsersReceived(response: Result(List(user.User), rsvp.Error))
  UpdatedEmailFilter(String)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UsersReceived(response) -> #(
      Model(..model, users: option.Some(response)),
      effect.none(),
    )
    UpdatedEmailFilter(email) -> {
      let email_filter = case email {
        "" -> option.None
        email -> option.Some(email)
      }
      #(
        Model(..model, email_filter:),
        user.list_all(
          page: model.page,
          with_email: email_filter,
          handler: UsersReceived,
        ),
      )
    }
  }
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  case shared.is_admin(shared) {
    False -> h.div([], [h.p([], [h.text("This page is for admins only.")])])
    True ->
      h.div([], [
        h.h1([], [h.text("Manage users")]),
        ui.search_input(
          label: "Email",
          name: "email",
          value: model.email_filter,
          on_input: UpdatedEmailFilter,
        ),
        case
          model.users
          |> option.unwrap(Ok([]))
        {
          Ok(users) -> {
            table.view(
              headings: ["ID", "Email", "Name", "Action"],
              rows: users
                |> list.map(fn(user) {
                  [
                    [h.text(user.id)],
                    [h.text(user.email)],
                    [h.text(user.name)],
                    [
                      h.a(
                        [
                          a.href(
                            "/user/" <> uri.percent_encode(user.id) <> "/edit",
                          ),
                        ],
                        [h.text("Edit")],
                      ),
                    ],
                  ]
                }),
            )
          }
          Error(_) -> {
            h.p([], [
              h.text(
                "An error occurred while fetching the list of users. Please try again.",
              ),
            ])
          }
        },
      ])
  }
}
