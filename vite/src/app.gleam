import gleam/result
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import modem

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Route {
  Home
  Search
}

type Model {
  Model(route: Route)
}

type Msg {
  OnRouteChanged(Route)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let route =
    modem.initial_uri()
    |> result.map(fn(uri) { uri.path_segments(uri.path) })
    |> fn(path) {
      case path {
        Ok(["search"]) -> Search
        _ -> Home
      }
    }

  #(Model(route), modem.init(on_url_change))
}

fn on_url_change(uri: Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["search"] -> OnRouteChanged(Search)
    _ -> OnRouteChanged(Home)
  }
}

fn update(_, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChanged(route) -> #(Model(route), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.nav([], [
      h.a([a.href("/")], [element.text("Go to home")]),
      h.a([a.href("/search")], [element.text("Go to search")]),
    ]),
    case model.route {
      Home -> h.h1([], [element.text("You're on home")])
      Search -> h.h1([], [element.text("You're on search")])
    },
  ])
}
