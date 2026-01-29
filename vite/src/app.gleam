import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event
import modem
import pages/admin/users as manage_users
import pages/auth
import pages/auth/login
import pages/auth/sign_up
import pages/edit_user
import pages/event/edit as edit_event
import pages/event/view as view_event
import pages/home
import pages/not_found
import rsvp
import shared.{type Shared, Shared}
import user.{type User}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(page: Page, shared: Shared)
}

type Page {
  Home(home.Model)

  Login(login.Model)
  SignUp(sign_up.Model)

  CreateEvent(edit_event.Model)
  UpdateEvent(edit_event.Model)
  ViewEvent(view_event.Model)

  EditUser(edit_user.Model)
  ManageUsers(manage_users.Model)

  NotFound(not_found.Model)
}

fn change_page(
  from old_url: Uri,
  to new_url: Uri,
  with shared: Shared,
) -> #(Page, Effect(Msg)) {
  let path_segments = uri.path_segments(new_url.path)

  case path_segments {
    [] ->
      home.init()
      |> update_page_with(Home, GotHomeMsg)
    ["login"] ->
      login.init(case uri.path_segments(old_url.path) {
        ["login"] | ["register"] -> uri.empty
        _ -> old_url
      })
      |> update_page_with(Login, GotLoginMsg)
    ["register"] ->
      sign_up.init(case uri.path_segments(old_url.path) {
        ["login"] | ["register"] -> uri.empty
        _ -> old_url
      })
      |> update_page_with(SignUp, GotSignUpMsg)

    ["event", "create"] ->
      edit_event.init(shared, edit_event.Create)
      |> update_page_with(CreateEvent, GotCreateEventMsg)

    ["event", id_url_string] -> {
      parse_percent_encoded_id(id_url_string, fn(id) {
        view_event.init(id)
        |> update_page_with(ViewEvent, GotViewEventMsg)
      })
    }

    ["event", id_url_string, "edit"] -> {
      parse_percent_encoded_id(id_url_string, fn(id) {
        edit_event.init(shared, edit_event.Update(id))
        |> update_page_with(UpdateEvent, GotUpdateEventMsg)
      })
    }

    ["user", id_url_string, "edit"] -> {
      parse_percent_encoded_id(id_url_string, fn(id) {
        edit_user.init(id, shared)
        |> update_page_with(EditUser, GotEditUserMsg)
      })
    }

    ["admin", "users"] -> {
      manage_users.init(shared)
      |> update_page_with(ManageUsers, GotManageUsersMsg)
    }

    _ ->
      not_found.init()
      |> update_page_with(NotFound, GotNotFoundMsg)
  }
}

fn parse_percent_encoded_id(
  encoded_id: String,
  f: fn(String) -> #(Page, Effect(Msg)),
) -> #(Page, Effect(Msg)) {
  case uri.percent_decode(encoded_id) {
    Ok(id) -> {
      f(id)
    }
    Error(_) -> {
      not_found.init()
      |> update_page_with(NotFound, GotNotFoundMsg)
    }
  }
}

fn update_with(
  init_result: #(page_model, Effect(page_msg)),
  to_page: fn(page_model) -> Page,
  to_msg: fn(page_msg) -> Msg,
  model: Model,
) -> #(Model, Effect(Msg)) {
  let #(page_model, page_effect) = init_result

  #(
    Model(..model, page: to_page(page_model)),
    page_effect |> effect.map(to_msg),
  )
}

fn update_page_with(
  init_result: #(page_model, Effect(page_msg)),
  to_page: fn(page_model) -> Page,
  to_msg: fn(page_msg) -> Msg,
) -> #(Page, Effect(Msg)) {
  let #(page_model, page_effect) = init_result

  #(to_page(page_model), page_effect |> effect.map(to_msg))
}

type Msg {
  UrlChanged(Uri)
  CurrentUserReceived(Result(User, rsvp.Error))
  UserRequestedLogout
  LogoutResponseReceived(Result(Response(String), rsvp.Error))
  GotHomeMsg(home.Msg)
  GotNotFoundMsg(not_found.Msg)
  GotLoginMsg(login.Msg)
  GotSignUpMsg(sign_up.Msg)

  GotCreateEventMsg(edit_event.Msg)
  GotUpdateEventMsg(edit_event.Msg)
  GotViewEventMsg(view_event.Msg)

  GotEditUserMsg(edit_user.Msg)
  GotManageUsersMsg(manage_users.Msg)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let url =
    modem.initial_uri()
    |> result.unwrap(uri.empty)
  let shared = Shared(current_url: url, user: user.Unknown)

  let #(page, page_effect) = change_page(from: uri.empty, to: url, with: shared)

  #(
    Model(page: page, shared:),
    effect.batch([
      page_effect,
      modem.init(UrlChanged),
      user.get_current_user(CurrentUserReceived),
    ]),
  )
}

fn logout() {
  rsvp.post(
    auth.api_prefix <> "/logout",
    json.object([]),
    rsvp.expect_ok_response(LogoutResponseReceived),
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page {
    UrlChanged(new_url), _ -> {
      let #(page, page_effect) =
        change_page(
          from: model.shared.current_url,
          to: new_url,
          with: model.shared,
        )

      #(
        Model(page:, shared: Shared(..model.shared, current_url: new_url)),
        effect.batch([page_effect, user.get_current_user(CurrentUserReceived)]),
      )
    }

    CurrentUserReceived(response), _ -> {
      #(
        Model(
          ..model,
          shared: Shared(..model.shared, user: case response {
            Ok(user) ->
              case user.is_logged_in {
                True -> user.Authenticated(user)
                False -> user.Unauthenticated
              }
            Error(error) -> {
              user.Unauthenticated
            }
          }),
        ),
        effect.none(),
      )
    }

    UserRequestedLogout, _ -> {
      #(model, logout())
    }

    LogoutResponseReceived(Ok(_)), _ -> {
      #(
        Model(
          ..model,
          shared: Shared(..model.shared, user: user.Unauthenticated),
        ),
        effect.none(),
      )
    }

    LogoutResponseReceived(Error(_)), _ -> {
      #(model, effect.none())
    }

    GotNotFoundMsg(sub_msg), NotFound(sub_model) ->
      not_found.update(sub_model, sub_msg)
      |> update_with(NotFound, GotNotFoundMsg, model)

    GotHomeMsg(sub_msg), Home(sub_model) ->
      home.update(sub_model, sub_msg)
      |> update_with(Home, GotHomeMsg, model)

    GotLoginMsg(sub_msg), Login(sub_model) ->
      login.update(sub_model, sub_msg)
      |> update_with(Login, GotLoginMsg, model)

    GotSignUpMsg(sub_msg), SignUp(sub_model) ->
      sign_up.update(sub_model, sub_msg)
      |> update_with(SignUp, GotSignUpMsg, model)

    GotCreateEventMsg(sub_msg), CreateEvent(sub_model) ->
      edit_event.update(sub_model, sub_msg)
      |> update_with(CreateEvent, GotCreateEventMsg, model)

    GotUpdateEventMsg(sub_msg), UpdateEvent(sub_model) ->
      edit_event.update(sub_model, sub_msg)
      |> update_with(UpdateEvent, GotUpdateEventMsg, model)

    GotViewEventMsg(sub_msg), ViewEvent(sub_model) ->
      view_event.update(sub_model, sub_msg)
      |> update_with(ViewEvent, GotViewEventMsg, model)

    GotEditUserMsg(sub_msg), EditUser(sub_model) ->
      edit_user.update(sub_model, sub_msg)
      |> update_with(EditUser, GotEditUserMsg, model)

    GotManageUsersMsg(sub_msg), ManageUsers(sub_model) ->
      manage_users.update(sub_model, sub_msg)
      |> update_with(ManageUsers, GotManageUsersMsg, model)

    _, _ -> panic as "Mismatched page and msg!"
  }
}

fn view_page(page: Page, shared: Shared) {
  case page {
    Home(sub_model) ->
      home.view(sub_model, shared)
      |> element.map(GotHomeMsg)

    NotFound(sub_model) ->
      not_found.view(sub_model)
      |> element.map(GotNotFoundMsg)

    SignUp(sub_model) ->
      sign_up.view(sub_model)
      |> element.map(GotSignUpMsg)
    Login(sub_model) ->
      login.view(sub_model)
      |> element.map(GotLoginMsg)

    CreateEvent(sub_model) ->
      edit_event.view(sub_model)
      |> element.map(GotCreateEventMsg)

    UpdateEvent(sub_model) ->
      edit_event.view(sub_model)
      |> element.map(GotUpdateEventMsg)

    ViewEvent(sub_model) ->
      view_event.view(sub_model, shared)
      |> element.map(GotViewEventMsg)

    EditUser(sub_model) ->
      edit_user.view(sub_model)
      |> element.map(GotEditUserMsg)

    ManageUsers(sub_model) ->
      manage_users.view(sub_model, shared)
      |> element.map(GotManageUsersMsg)
  }
}

fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.nav([], [
      h.a([a.href("/")], [element.text("Home")]),
      h.a([a.href("/event/create")], [element.text("Create event")]),
      case model.shared.user {
        user.Authenticated(_) ->
          h.button([event.on_click(UserRequestedLogout)], [
            element.text("Log out"),
          ])
        user.Unauthenticated | user.Unknown ->
          element.fragment([
            h.a([a.href("/login")], [element.text("Login")]),
            h.a([a.href("/register")], [element.text("Sign up")]),
          ])
      },
      case shared.is_admin(model.shared) {
        True -> h.a([a.href("/admin/users")], [h.text("Manage users")])
        False -> element.none()
      },
    ]),
    h.div([], [view_page(model.page, model.shared)]),
  ])
}
