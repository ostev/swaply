import api
import gleam/http
import gleam/http/response.{type Response}
import gleam/json
import gleam/result
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import modem
import page/admin/users as manage_users
import page/auth
import page/auth/login
import page/auth/sign_up
import page/edit_user
import page/home
import page/listing/edit as edit_listing
import page/listing/view as view_listing
import page/not_found
import phosphor
import rsvp
import shared.{type Shared, Shared}
import sketch
import sketch/css
import sketch/css/angle
import sketch/css/length
import sketch/css/media
import sketch/css/transform
import sketch/lustre as sketch_lustre
import sketch/lustre/element/html as h
import ui
import ui/colors
import ui/fonts
import ui/nav
import ui/styles
import user.{type User}

pub fn main() {
  let assert Ok(stylesheet) =
    sketch_lustre.construct(fn(stylesheet) {
      stylesheet
      |> sketch.global(css.global("html, body", [fonts.merriweather()]))
    })

  let app = lustre.application(init, update, view(_, stylesheet))
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(page: Page, shared: Shared, nav: nav.State)
}

type Page {
  Home(home.Model)

  Login(login.Model)
  SignUp(sign_up.Model)

  CreateListing(edit_listing.Model)
  UpdateListing(edit_listing.Model)
  ViewListing(view_listing.Model)

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

    ["listing", "create"] ->
      edit_listing.init(shared, edit_listing.Create)
      |> update_page_with(CreateListing, GotCreateListingMsg)

    ["listing", id_url_string] -> {
      parse_percent_encoded_id(id_url_string, fn(id) {
        view_listing.init(id)
        |> update_page_with(ViewListing, GotViewListingMsg)
      })
    }

    ["listing", id_url_string, "edit"] -> {
      parse_percent_encoded_id(id_url_string, fn(id) {
        edit_listing.init(shared, edit_listing.Update(id))
        |> update_page_with(UpdateListing, GotUpdateListingMsg)
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
  ToggleNav

  UrlChanged(Uri)
  CurrentUserReceived(Result(User, rsvp.Error))
  UserRequestedLogout
  LogoutResponseReceived(Result(Response(String), rsvp.Error))
  GotHomeMsg(home.Msg)
  GotNotFoundMsg(not_found.Msg)
  GotLoginMsg(login.Msg)
  GotSignUpMsg(sign_up.Msg)

  GotCreateListingMsg(edit_listing.Msg)
  GotUpdateListingMsg(edit_listing.Msg)
  GotViewListingMsg(view_listing.Msg)

  GotEditUserMsg(edit_user.Msg)
  GotManageUsersMsg(manage_users.Msg)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let url =
    modem.initial_uri()
    |> result.unwrap(uri.empty)
  let shared =
    shared.new(url)
    |> result.lazy_unwrap(fn() { panic as "CSRF token not found!" })

  let #(page, page_effect) = change_page(from: uri.empty, to: url, with: shared)

  #(
    Model(page: page, shared:, nav: nav.Closed),
    effect.batch([
      page_effect,
      modem.init(UrlChanged),
      user.get_current_user(CurrentUserReceived),
    ]),
  )
}

fn logout(csrf_token: String) {
  api.send(
    body: json.object([]),
    to: auth.api_root <> "/logout",
    with: http.Post,
    handler: rsvp.expect_ok_response(LogoutResponseReceived),
    with_token: csrf_token,
  )
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page {
    ToggleNav, _ -> {
      #(Model(..model, nav: nav.toggle(model.nav)), effect.none())
    }

    UrlChanged(new_url), _ -> {
      let #(page, page_effect) =
        change_page(
          from: model.shared.current_url,
          to: new_url,
          with: model.shared,
        )

      #(
        Model(
          ..model,
          page:,
          shared: Shared(..model.shared, current_url: new_url),
        ),
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
            Error(_) -> {
              user.Unauthenticated
            }
          }),
        ),
        effect.none(),
      )
    }

    UserRequestedLogout, _ -> {
      #(
        model,
        logout(model.shared.csrf_token)
          |> result.lazy_unwrap(fn() {
            panic as "Logout URL failed to parse. This shouldn't happen."
          }),
      )
    }

    LogoutResponseReceived(Ok(_)), _ -> {
      #(
        Model(
          ..model,
          shared: Shared(..model.shared, user: user.Unauthenticated),
        ),
        modem.load(
          uri.origin(model.shared.current_url)
          |> result.map(uri.parse)
          |> result.flatten
          |> result.unwrap(model.shared.current_url),
        ),
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
      login.update(model.shared, sub_model, sub_msg)
      |> update_with(Login, GotLoginMsg, model)

    GotSignUpMsg(sub_msg), SignUp(sub_model) ->
      sign_up.update(model.shared, sub_model, sub_msg)
      |> update_with(SignUp, GotSignUpMsg, model)

    GotCreateListingMsg(sub_msg), CreateListing(sub_model) ->
      edit_listing.update(model.shared, sub_model, sub_msg)
      |> update_with(CreateListing, GotCreateListingMsg, model)

    GotUpdateListingMsg(sub_msg), UpdateListing(sub_model) ->
      edit_listing.update(model.shared, sub_model, sub_msg)
      |> update_with(UpdateListing, GotUpdateListingMsg, model)

    GotViewListingMsg(sub_msg), ViewListing(sub_model) ->
      view_listing.update(model.shared, sub_model, sub_msg)
      |> update_with(ViewListing, GotViewListingMsg, model)

    GotEditUserMsg(sub_msg), EditUser(sub_model) ->
      edit_user.update(model.shared, sub_model, sub_msg)
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

    CreateListing(sub_model) ->
      edit_listing.view(sub_model)
      |> element.map(GotCreateListingMsg)

    UpdateListing(sub_model) ->
      edit_listing.view(sub_model)
      |> element.map(GotUpdateListingMsg)

    ViewListing(sub_model) ->
      view_listing.view(sub_model, shared)
      |> element.map(GotViewListingMsg)

    EditUser(sub_model) ->
      edit_user.view(sub_model)
      |> element.map(GotEditUserMsg)

    ManageUsers(sub_model) ->
      manage_users.view(sub_model, shared)
      |> element.map(GotManageUsersMsg)
  }
}

fn nav(model: Model) -> Element(Msg) {
  h.nav(
    css.class([
      css.padding_inline(length.px(10)),
      css.padding_block(length.px(15)),

      css.background_color("#E7C6FF98"),
      css.backdrop_filter("blur(20px)"),

      css.media(media.min_width(styles.mobile_width()), [
        css.position("sticky"),
        css.top(length.px(0)),
      ]),

      css.border_radius(length.px(6)),
    ]),
    [],
    [
      h.div(
        css.class([
          css.display("flex"),
          css.align_items("center"),
          css.justify_content("space-between"),

          css.gap(length.px(10)),
        ]),
        [],
        [
          action_nav(),

          h.div(
            css.class([
              css.display("flex"),
              css.flex_direction("row"),
              css.align_content("center"),
              css.justify_content("space-between"),
              css.gap(length.px(10)),
              css.color(colors.text),

              styles.hidden_on_mobile(),
            ]),
            [],
            [
              auth_nav(model.shared),
            ],
          ),

          h.div(css.class([styles.hidden_on_desktop()]), [], [
            nav.menu_button(model.nav, ToggleNav),
          ]),
        ],
      ),

      h.div(
        css.class([
          styles.hidden_on_desktop(),

          css.transition("max-height 0.5s ease-in-out"),
          css.max_height_(case model.nav {
            nav.Open -> "5.5rem"
            nav.Closed -> "0"
          }),

          css.overflow("hidden"),
        ]),
        [],
        [
          h.div(
            css.class([
              css.padding_left(length.px(4)),
              css.padding_right(length.px(8)),
              css.padding_bottom(length.px(8)),

              css.display("flex"),
              css.flex_direction("column"),
              css.align_content("center"),
              css.justify_content("start"),
              css.gap(length.px(10)),
              css.color(colors.text),
            ]),
            [],
            [
              auth_nav(model.shared),
            ],
          ),
        ],
      ),
    ],
  )
}

fn auth_nav(shared: Shared) -> Element(Msg) {
  element.fragment([
    case shared.is_admin(shared) {
      True -> ui.link_button(ui.Primary, "Manage users", to: "/admin/users")
      False -> element.none()
    },
    ..case shared.user {
      user.Authenticated(_) -> [
        ui.button(ui.Primary, "Log out", UserRequestedLogout),
      ]
      user.Unauthenticated | user.Unknown -> [
        ui.link_button(ui.Primary, text: "Login", to: "/login"),
        ui.link_button(ui.Primary, text: "Sign up", to: "/register"),
      ]
    }
  ])
}

fn action_nav() -> Element(Msg) {
  h.div(
    css.class([
      css.display("flex"),
      css.align_items("center"),
      css.justify_content("start"),
      css.gap(length.px(20)),
      css.flex_grow(2),
    ]),
    [],
    [
      h.a(
        css.class([
          css.display("flex"),
          css.align_items("center"),
          css.justify_content("start"),
          css.gap(length.px(10)),
          css.color(colors.text),
          css.text_decoration("none"),
        ]),
        [
          a.href("/"),
          a.title("Home"),
        ],
        [
          h.div(styles.rotate_hover(-10.0), [], [
            phosphor.tag_regular([a.style("font-size", "48px")]),
          ]),

          h.span(
            css.class([
              css.compose(styles.rotate_hover(2.0)),
              css.media(media.max_width(length.px(450)), [css.display("none")]),
            ]),
            [],
            [ui.h1("Swaply")],
          ),
        ],
      ),
      h.a(
        css.class([
          css.color(colors.text),

          css.display("flex"),
          css.align_items("center"),
          css.justify_content("start"),

          css.selector(":hover .new_listing", [
            css.clip_path("inset(0 0 0 0)"),
          ]),

          css.selector(">.new_listing_icon", [
            css.transition("transform 0.3s " <> styles.energetic_hover_curve),
          ]),

          css.selector(":hover .new_listing_icon", [
            css.transform([transform.rotate(angle.deg(-90.0))]),
          ]),

          css.overflow("hidden"),
        ]),
        [
          a.href("/listing/create"),
          a.title("Create listing"),
        ],
        [
          phosphor.plus_circle_regular([
            a.class("new_listing_icon"),
            a.style("font-size", "48px"),
          ]),

          h.span(
            css.class([
              css.white_space("nowrap"),
              css.clip_path("inset(0 110% 0 0)"),
              css.transition("clip-path 0.3s " <> styles.energetic_hover_curve),

              styles.hidden_on_mobile(),
            ]),
            [a.class("new_listing")],
            [h.text("Create listing")],
          ),
        ],
      ),
    ],
  )
}

fn view(model: Model, stylesheet: sketch.StyleSheet) -> Element(Msg) {
  use <- sketch_lustre.render(stylesheet:, in: [sketch_lustre.node()])

  h.div_([], [
    nav(model),
    h.div_([], [view_page(model.page, model.shared)]),
  ])
}
