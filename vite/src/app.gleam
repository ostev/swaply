import gleam/result
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import modem
import pages/auth/login
import pages/home
import pages/not_found

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(page: Page)
}

type Page {
  Home(home.Model)
  Login(login.Model)
  NotFound(not_found.Model)
}

fn init_page_from_url(url: Uri) -> #(Page, Effect(Msg)) {
  let path_segments = uri.path_segments(url.path)

  case path_segments {
    [] ->
      home.init()
      |> update_page_with(Home, GotHomeMsg)
    ["login"] ->
      login.init(uri.empty)
      |> update_page_with(Login, GotLoginMsg)
    _ ->
      not_found.init()
      |> update_page_with(NotFound, GotNotFoundMsg)
  }
}

fn update_with(
  init_result: #(page_model, Effect(page_msg)),
  to_page: fn(page_model) -> Page,
  to_msg: fn(page_msg) -> Msg,
  _model: Model,
) -> #(Model, Effect(Msg)) {
  let #(page_model, page_effect) = init_result

  #(Model(page: to_page(page_model)), page_effect |> effect.map(to_msg))
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
  GotHomeMsg(home.Msg)
  GotNotFoundMsg(not_found.Msg)
  GotLoginMsg(login.Msg)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let #(page, page_effect) =
    init_page_from_url(
      modem.initial_uri()
      |> result.unwrap(uri.empty),
    )

  #(Model(page: page), effect.batch([page_effect, modem.init(UrlChanged)]))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page {
    UrlChanged(new_url), _ -> {
      let #(page, page_effect) = init_page_from_url(new_url)

      #(Model(page:), page_effect)
    }
    GotHomeMsg(sub_msg), Home(sub_model) ->
      home.update(sub_model, sub_msg)
      |> update_with(Home, GotHomeMsg, model)

    GotLoginMsg(sub_msg), Login(sub_model) ->
      login.update(sub_model, sub_msg)
      |> update_with(Login, GotLoginMsg, model)

    GotNotFoundMsg(sub_msg), NotFound(sub_model) ->
      not_found.update(sub_model, sub_msg)
      |> update_with(NotFound, GotNotFoundMsg, model)

    _, _ -> todo
  }
}

fn view_page(page: Page) {
  case page {
    Home(sub_model) ->
      home.view(sub_model)
      |> element.map(GotHomeMsg)
    NotFound(sub_model) ->
      not_found.view(sub_model)
      |> element.map(GotNotFoundMsg)
    Login(sub_model) ->
      login.view(sub_model)
      |> element.map(GotLoginMsg)
  }
}

fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.nav([], [
      h.a([a.href("/")], [element.text("Go to home")]),
      h.a([a.href("/login")], [element.text("Go to login")]),
    ]),
    h.div([], [view_page(model.page)]),
  ])
}
