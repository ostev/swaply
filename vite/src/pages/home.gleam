import event
import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/string
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import rsvp
import shared.{type Shared}
import tempo
import tempo/instant
import ui
import user

pub type Model {
  Model(
    search_query: String,
    filter: event.SearchFilter,
    page: Int,
    events: Option(event.SearchResults),
  )
}

pub type Msg {
  UpdateSearchQuery(String)
  UpdatedFilter(event.SearchFilter)
  FetchedSearchResults(Result(event.SearchResults, rsvp.Error))
  ChangePage(Int)
}

pub fn init() -> #(Model, Effect(Msg)) {
  let filter =
    event.SearchFilter(
      only_owned: False,
      start_date: option.None,
      end_date: option.None,
    )
  let page = 0

  #(
    Model(search_query: "", filter:, page:, events: option.None),
    event.search(
      query: "",
      page:,
      filter:,
      timestamp: instant.now(),
      handler: FetchedSearchResults,
    ),
  )
}

fn search(model: Model) -> Effect(Msg) {
  event.search(
    query: model.search_query,
    page: model.page,
    filter: model.filter,
    timestamp: instant.now(),
    handler: FetchedSearchResults,
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
          let new_model = Model(..model, search_query: new_query, page: 0)
          #(new_model, search(new_model))
        }
      }
    }

    UpdatedFilter(new_filter) -> {
      case new_filter == model.filter {
        True -> {
          #(model, effect.none())
        }
        False -> {
          let new_model = Model(..model, filter: new_filter)
          #(new_model, search(new_model))
        }
      }
    }

    ChangePage(page) -> {
      let new_model = Model(..model, page:)
      #(new_model, search(new_model))
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

    FetchedSearchResults(Error(_error)) -> {
      #(Model(..model, events: option.None), effect.none())
    }
  }
}

fn date_filter_control(
  label: String,
  name: String,
  value: Option(tempo.Date),
  on_input: fn(Option(tempo.Date)) -> msg,
) -> Element(msg) {
  h.div([], [
    ui.toggle_input(
      label: "Filter by " <> string.lowercase(label) <> "?",
      name: "toggle_" <> name,
      is_checked: option.is_some(value),
      on_input: todo,
    ),
  ])
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  h.div([], [
    h.h1([], [h.text("Events")]),
    h.h2([], [
      h.text(
        "Hello there! "
        <> case shared.user {
          user.Authenticated(user) -> "Your name is " <> user.name
          user.Unauthenticated -> "You have not signed in."
          user.Unknown -> ""
        },
      ),
    ]),
    h.input([
      a.value(model.search_query),
      a.placeholder("Search for events..."),
      e.debounce(e.on_input(UpdateSearchQuery), 100),
    ]),
    case shared.user {
      user.Authenticated(_) -> {
        ui.toggle_input(
          label: "Only your events?",
          name: "filter_owned",
          is_checked: model.filter.only_owned,
          on_input: fn(is_checked) {
            UpdatedFilter(
              event.SearchFilter(..model.filter, only_owned: is_checked),
            )
          },
        )
      }
      user.Unknown | user.Unauthenticated -> element.none()
    },
    case model.events {
      option.Some(search_result) -> {
        h.div([], [
          h.ol(
            [],
            search_result.events
              |> list.map(fn(event) {
                h.li([], [
                  ui.event_card_view(
                    event,
                    is_editable: shared
                      |> shared.get_user
                      |> option.map(fn(user) { user.id == event.manager })
                      |> option.unwrap(False),
                  ),
                ])
              }),
          ),

          h.div([], [
            ui.page_control(
              page: model.page,
              of: search_result.number_of_pages,
              with: ChangePage,
            ),
          ]),
        ])
      }
      option.None -> {
        h.text(
          "An error occurred while searching for events. Please try again.",
        )
      }
    },
  ])
}
