import gleam/list
import gleam/option.{type Option}
import gleam/uri
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import rsvp
import shared.{type Shared}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import ui
import ui/button
import ui/input
import ui/layout
import ui/table
import user

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
  h.div(layout.row(layout.Center), [], [
    case shared.is_unknown(shared) || shared.is_admin(shared) {
      False -> ui.panel(ui.ErrorPanel, True, "This page is for admins only.")
      True ->
        h.div(
          css.class([
            css.width(length.percent(100)),
            css.max_width(length.rem(30.0)),
          ]),
          [],
          [
            ui.h2(css.class([css.text_align("center")]), "Manage users"),
            h.div(
              css.class([
                css.margin_bottom(length.px(12)),
                css.width(length.percent(100)),

                css.compose(layout.row(layout.Center)),
              ]),
              [],
              [
                h.div(
                  css.class([
                    css.width(length.percent(100)),
                    css.max_width(length.rem(25.0)),
                  ]),
                  [],
                  [
                    input.search(
                      label: "Email",
                      name: "email",
                      placeholder: "Search by email...",
                      value: model.email_filter |> option.unwrap(""),
                      on_input: UpdatedEmailFilter,
                    ),
                  ],
                ),
              ],
            ),
            case model.users {
              option.Some(Ok(users)) -> {
                table.view(
                  headings: ["ID", "Email", "Name", "Action"],
                  rows: users
                    |> list.map(fn(user) {
                      [
                        [h.text(user.id)],
                        [h.text(user.email)],
                        [h.text(user.name)],
                        [
                          button.link(
                            button.Primary,
                            "Edit",
                            "/user/" <> uri.percent_encode(user.id) <> "/edit",
                          ),
                        ],
                      ]
                    }),
                )
              }
              option.Some(Error(_)) ->
                ui.panel(
                  ui.ErrorPanel,
                  True,
                  "An error occurred while fetching the list of users. Please try again.",
                )
              option.None -> element.none()
            },
          ],
        )
    },
  ])
}
