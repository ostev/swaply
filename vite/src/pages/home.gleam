import event
import gleam/list
import gleam/option.{type Option}
import gleam/order
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import rsvp
import shared.{type Shared}
import tempo/instant
import ui

pub type Model {
  Model(search_query: String, events: Option(event.SearchResults))
}

pub type Msg {
  UpdateSearchQuery(String)
  FetchedSearchResults(Result(event.SearchResults, rsvp.Error))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(search_query: "", events: option.None),
    event.search_events(
      query: "",
      page: 0,
      timestamp: instant.now(),
      handler: FetchedSearchResults,
    ),
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
            event.search_events(
              query: new_query,
              page: 0,
              timestamp: instant.now(),
              handler: FetchedSearchResults,
            ),
          )
        }
      }
    }

    FetchedSearchResults(Ok(events)) -> {
      #(
        Model(..model, events: case model.events {
          option.Some(previous) -> {
            option.Some(
              // If we've received the new search results after the previous ones,
              // update the page. Otherwise, use the old results.
              case events.timestamp |> instant.compare(previous.timestamp) {
                order.Gt | order.Eq -> {
                  events
                }
                _ -> {
                  previous
                }
              },
            )
          }
          option.None -> option.Some(events)
        }),
        effect.none(),
      )
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
      e.debounce(e.on_input(UpdateSearchQuery), 100),
    ]),
    case model.events {
      option.Some(search_result) -> {
        h.ol(
          [],
          search_result.events
            |> list.map(fn(event) { h.li([], [ui.event_card_view(event)]) }),
        )
      }
      option.None -> {
        h.text(
          "An error occurred while searching for events. Please try again.",
        )
      }
    },
  ])
}
