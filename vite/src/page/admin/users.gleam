import gleam/list
import gleam/option.{type Option}
import gleam/uri
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import rsvp
import search
import shared.{type Shared}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import tempo/instant
import ui
import ui/button
import ui/input
import ui/layout
import ui/styles
import ui/table
import user.{type User}

pub type Model {
  Model(
    page: Int,
    filter: user.SearchFilter,
    users: Option(Result(search.Results(User), rsvp.Error)),
  )
}

pub fn init(shared: Shared) -> #(Model, Effect(Msg)) {
  let page = 0
  let filter = user.SearchFilter(email: option.None, only_admins: False)

  #(
    Model(page:, filter:, users: option.None),
    effect.batch([
      shared.check_authenticated(shared),
      user.list_all(
        page:,
        with: filter,
        at_timestamp: instant.now(),
        handler: UsersReceived,
      ),
    ]),
  )
}

pub type Msg {
  UsersReceived(response: Result(search.Results(User), rsvp.Error))
  UpdateFilter(user.SearchFilter)
  ChangePage(Int)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UsersReceived(response) -> #(
      Model(..model, users: option.Some(response)),
      effect.none(),
    )
    UpdateFilter(filter) -> {
      #(
        Model(..model, filter:, page: 0),
        user.list_all(
          page: 0,
          with: filter,
          at_timestamp: instant.now(),
          handler: UsersReceived,
        ),
      )
    }

    ChangePage(page) -> {
      let new_model = Model(..model, page:)
      #(
        new_model,
        user.list_all(
          page:,
          with: model.filter,
          at_timestamp: instant.now(),
          handler: UsersReceived,
        ),
      )
    }
  }
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  h.div(layout.column(layout.Center), [], [
    case shared.is_unknown(shared) || shared.is_admin(shared) {
      False -> ui.panel(ui.ErrorPanel, True, "This page is for admins only.")
      True ->
        h.div(
          css.class([
            css.width(length.percent(100)),
            css.max_width(length.rem(30.0)),
            css.margin_top(length.px(24)),
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
                h.div(styles.search_card(), [], [
                  input.search(
                    label: "Email",
                    name: "email",
                    placeholder: "Search by email...",
                    value: model.filter.email |> option.unwrap(""),
                    on_input: fn(email) {
                      case email {
                        "" ->
                          UpdateFilter(
                            user.SearchFilter(
                              ..model.filter,
                              email: option.None,
                            ),
                          )
                        _ ->
                          UpdateFilter(
                            user.SearchFilter(
                              ..model.filter,
                              email: option.Some(email),
                            ),
                          )
                      }
                    },
                  ),

                  input.toggle(
                    label: "Only admins?",
                    name: "only_admins",
                    is_checked: model.filter.only_admins,
                    on_input: fn(only_admins) {
                      UpdateFilter(
                        user.SearchFilter(..model.filter, only_admins:),
                      )
                    },
                  ),
                ]),
              ],
            ),
            case model.users {
              option.Some(Ok(users)) -> {
                element.fragment([
                  table.view(
                    headings: ["ID", "Email", "Name", "Action"],
                    rows: users.values
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
                  ),
                  h.div(css.class([css.margin_top(length.px(24))]), [], [
                    ui.paginator(
                      page: model.page,
                      of: users.number_of_pages,
                      with: ChangePage,
                    ),
                  ]),
                ])
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
