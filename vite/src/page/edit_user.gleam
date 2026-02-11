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
import lustre/event as e
import modem
import page/auth
import rsvp
import shared.{type Shared}
import sketch/css
import sketch/lustre/element/html as h
import ui
import ui/layout
import ui/styles
import ui/table
import user.{type User}

pub type Model {
  Model(
    user: Option(Result(User, rsvp.Error)),
    form: Option(Form),
    update_error: Option(user.UpdateError),
    delete_error: Option(rsvp.Error),
  )
}

pub type Form {
  Form(email: String, is_admin: Bool)
}

pub fn init(user_id: String, shared: Shared) -> #(Model, Effect(Msg)) {
  #(
    Model(
      user: option.None,
      form: option.None,
      update_error: option.None,
      delete_error: option.None,
    ),
    effect.batch([
      shared.check_authentication(shared),
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

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserReceived(result) -> {
      echo result
      #(
        Model(
          ..model,
          user: option.Some(result),
          form: result
            |> option.from_result
            |> option.map(fn(user) {
              Form(email: user.email, is_admin: user.is_admin)
            }),
        ),
        effect.none(),
      )
    }
    UpdateForm(form) -> {
      #(Model(..model, form: option.Some(form)), effect.none())
    }
    SubmitForm -> {
      #(model, case model.form, model.user {
        option.Some(form), option.Some(Ok(user)) -> {
          submit(form, user)
        }
        _, _ -> effect.none()
      })
    }
    DeleteUser -> {
      case model.user {
        option.Some(Ok(user)) -> #(
          model,
          user.delete(user.id, DeleteResponseReceived)
            |> result.unwrap(effect.none()),
        )
        _ -> #(model, effect.none())
      }
    }

    UpdateResponseReceived(Ok(_)) -> #(
      model,
      modem.push("/admin/users", option.None, option.None),
    )
    UpdateResponseReceived(Error(error)) -> #(
      Model(..model, update_error: option.Some(error)),
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

fn submit(form: Form, user: User) {
  user.update(
    id: user.id,
    email: option.Some(form.email),
    is_admin: option.Some(form.is_admin),
    handler: UpdateResponseReceived,
  )
  |> result.unwrap(effect.none())
}

pub fn view(model: Model) -> Element(Msg) {
  h.div(layout.row(layout.Center), [], [
    case model.form {
      option.None -> element.none()
      option.Some(form) -> {
        h.form(
          css.class([css.compose(styles.card())]),
          [
            e.on_submit(fn(_) { SubmitForm }),
          ],
          [
            ui.input_(
              type_: "text",
              label: "Email",
              name: "email",
              value: option.Some(form.email),
              on_input: fn(email) { UpdateForm(Form(..form, email:)) },
              is_valid: form.email |> string.contains("@"),
            ),
            ui.toggle_input(
              label: "Is admin?",
              name: "is_admin",
              is_checked: form.is_admin,
              on_input: fn(is_admin) { UpdateForm(Form(..form, is_admin:)) },
            ),

            h.div(layout.row(layout.SpaceBetween), [], [
              ui.button(ui.Danger, "Delete", DeleteUser),
              ui.submit(ui.Regular, "Update"),
            ]),
          ],
        )
      }
    },

    case model.update_error {
      option.Some(error) -> {
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
  ])
}
