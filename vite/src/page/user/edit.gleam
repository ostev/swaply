import gleam/option.{type Option}
import gleam/result
import gleam/string
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/event as e
import modem
import rsvp
import shared.{type Shared}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import ui
import ui/button.{button}
import ui/input
import ui/layout
import ui/styles
import user.{type User}

pub type UserData {
  UserData(user: User, form: Form)
}

pub type Model {
  Model(
    user: Option(Result(UserData, rsvp.Error)),
    updated: Option(Result(Nil, user.UpdateError)),
    delete_error: Option(rsvp.Error),
  )
}

pub type Form {
  Form(email: String, is_admin: Bool)
}

pub fn init(user_id: String, shared: Shared) -> #(Model, Effect(Msg)) {
  #(
    Model(user: option.None, updated: option.None, delete_error: option.None),
    effect.batch([
      shared.check_authenticated(shared),
      user.get(user_id, UserReceived),
    ]),
  )
}

pub type Msg {
  UserReceived(Result(User, rsvp.Error))
  UpdateForm(Form)
  UpdateResponseReceived(Result(User, user.UpdateError))
  DeleteResponseReceived(Result(Nil, rsvp.Error))
  SubmitForm
  DeleteUser
}

pub fn update(shared: Shared, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserReceived(result) -> {
      #(
        Model(
          ..model,
          user: option.Some(
            result
            |> result.map(fn(user) {
              UserData(user, Form(email: user.email, is_admin: user.is_admin))
            }),
          ),
        ),
        effect.none(),
      )
    }
    UpdateForm(form) -> {
      #(
        Model(
          ..model,
          user: model.user
            |> option.map(result.map(_, fn(data) { UserData(..data, form:) })),
          updated: option.None,
        ),
        effect.none(),
      )
    }
    SubmitForm -> {
      #(model, case model.user {
        option.Some(Ok(user)) -> {
          submit(user, with_token: shared.csrf_token)
        }
        _ -> effect.none()
      })
    }
    DeleteUser -> {
      case model.user {
        option.Some(Ok(data)) -> #(
          model,
          user.delete(data.user.id, DeleteResponseReceived, shared.csrf_token)
            |> result.unwrap(effect.none()),
        )
        _ -> #(model, effect.none())
      }
    }

    UpdateResponseReceived(Ok(_)) -> #(
      Model(..model, updated: option.Some(Ok(Nil))),
      effect.none(),
    )
    UpdateResponseReceived(Error(error)) -> #(
      Model(..model, updated: option.Some(Error(error))),
      effect.none(),
    )
    DeleteResponseReceived(Ok(_)) -> #(
      model,
      modem.push("/admin/users", option.None, option.None),
    )
    DeleteResponseReceived(Error(error)) -> #(
      Model(..model, delete_error: option.Some(error)),
      effect.none(),
    )
  }
}

fn submit(data: UserData, with_token csrf_token: String) {
  user.update(
    id: data.user.id,
    email: option.Some(data.form.email),
    is_admin: option.Some(data.form.is_admin),
    handler: UpdateResponseReceived,
    with_token: csrf_token,
  )
  |> result.unwrap(effect.none())
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  h.div(
    css.class([
      css.compose(layout.column(layout.Center)),
    ]),
    [],
    [
      case model.user {
        option.None -> element.none()
        option.Some(Error(_)) -> {
          ui.panel(
            ui.ErrorPanel,
            True,
            "An error occured while fetching information about this user.",
          )
        }
        option.Some(Ok(data)) -> {
          let form = data.form
          h.form(
            css.class([
              css.compose(styles.card()),
              css.margin(length.px(20)),
              css.width(length.percent(100)),
              css.max_width(length.rem(20.0)),
              css.padding(length.rem(1.0)),
            ]),
            [
              e.on_submit(fn(_) { SubmitForm }),
            ],
            [
              input.generic_(
                type_: "text",
                label: "Email",
                name: "email",
                value: option.Some(form.email),
                on_input: fn(email) { UpdateForm(Form(..form, email:)) },
                is_valid: form.email |> string.contains("@"),
              ),

              case shared.is_admin(shared) {
                True ->
                  input.toggle(
                    label: "Is admin?",
                    name: "is_admin",
                    is_checked: form.is_admin,
                    on_input: fn(is_admin) {
                      UpdateForm(Form(..form, is_admin:))
                    },
                  )
                False -> element.none()
              },

              h.div(
                css.class([
                  css.compose(layout.row(layout.SpaceBetween)),
                  css.margin_top(length.px(4)),
                ]),
                [],
                [
                  button(button.Danger, "Delete", DeleteUser),
                  button.submit(button.Primary, "Update"),
                ],
              ),
            ],
          )
        }
      },

      h.div(
        css.class([
          css.compose(layout.row(layout.End)),
          css.width(length.percent(100)),
          css.max_width(length.rem(22.0)),
        ]),
        [],
        [
          case shared.is_admin(shared) {
            True ->
              button.link(
                button.Primary,
                text: "Edit all users",
                to: "/admin/users",
              )
            False -> element.none()
          },
        ],
      ),

      case model.updated {
        option.Some(Ok(_)) -> {
          ui.panel(ui.InfoPanel, True, "Account updated!")
        }
        option.Some(Error(error)) -> {
          ui.panel(ui.ErrorPanel, True, case error {
            user.InvalidEmail -> "Please provide a valid new email."
            user.EmailAlreadyUsed ->
              "The new email you provided is already in use."
            _ -> "An error occurred. Please try again."
          })
        }
        option.None -> element.none()
      },

      case model.delete_error {
        option.Some(_) ->
          ui.panel(
            ui.ErrorPanel,
            True,
            "An error occurred while deleting the user. Please try again.",
          )
        option.None -> element.none()
      },
    ],
  )
}
