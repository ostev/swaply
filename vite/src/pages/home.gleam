import event
import gleam/list
import gleam/option.{type Option}
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import rsvp
import shared.{type Shared}

pub type Model {
  Model(search_query: String, events: Option(List(event.Event)))
}

pub type Msg {
  UpdateSearchQuery(String)
  FetchedSearchResults(Result(List(event.Event), rsvp.Error))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(search_query: "", events: option.Some([])),
    event.search_events("", 0, FetchedSearchResults),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UpdateSearchQuery(new_query) -> {
      case new_query == model.search_query {
        True -> {
          #(model, effect.none())
        }
        False -> {
          #(
            Model(..model, search_query: new_query),
            event.search_events(new_query, 0, FetchedSearchResults),
          )
        }
      }
    }

    FetchedSearchResults(Ok(events)) -> {
      #(Model(..model, events: option.Some(events)), effect.none())
    }

    FetchedSearchResults(Error(error)) -> {
      #(Model(..model, events: option.None), effect.none())
    }
  }
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  h.div([], [
    h.h1([], [h.text("Events")]),
    h.h2([], [
      h.text(
        "Hello there! "
        <> case shared.user {
          shared.Authenticated(user) -> "Your name is " <> user.name
          shared.Unauthenticated -> "You have not signed in."
          shared.Unknown -> ""
        },
      ),
    ]),
    h.input([
      a.value(model.search_query),
      a.placeholder("Search for events..."),
      e.on_input(UpdateSearchQuery),
    ]),
    case model.events {
      option.Some(events) -> {
        h.ol(
          [],
          events
            |> list.map(fn(event) { h.li([], [h.text(event.name)]) }),
        )
      }
      option.None -> {
        h.text("Error fetching events")
      }
    },
  ])
}
