import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/string
import listing
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
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
    filter: listing.SearchFilter,
    page: Int,
    listings: Option(listing.SearchResults),
  )
}

pub type Msg {
  UpdateSearchQuery(String)
  UpdatedFilter(listing.SearchFilter)
  FetchedSearchResults(Result(listing.SearchResults, rsvp.Error))
  ChangePage(Int)
}

pub fn init() -> #(Model, Effect(Msg)) {
  let filter =
    listing.SearchFilter(
      only_owned: False,
      start_date: option.None,
      end_date: option.None,
    )
  let page = 0

  #(
    Model(search_query: "", filter:, page:, listings: option.None),
    listing.search(
      query: "",
      page:,
      filter:,
      timestamp: instant.now(),
      handler: FetchedSearchResults,
    ),
  )
}

fn search(model: Model) -> Effect(Msg) {
  listing.search(
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

    FetchedSearchResults(Ok(listings)) -> {
      #(
        Model(..model, listings: case model.listings {
          option.Some(previous) -> {
            option.Some(
              // If we've received the new search results after the previous ones,
              // update the page. Otherwise, use the old results.
              case listings.timestamp |> instant.compare(previous.timestamp) {
                order.Gt | order.Eq -> {
                  listings
                }
                _ -> {
                  previous
                }
              },
            )
          }
          option.None -> option.Some(listings)
        }),
        effect.none(),
      )
    }

    FetchedSearchResults(Error(_error)) -> {
      #(Model(..model, listings: option.None), effect.none())
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
    h.h1([], [h.text("Listings")]),
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
      a.placeholder("Search for listings..."),
      e.debounce(e.on_input(UpdateSearchQuery), 200),
    ]),
    case shared.user {
      user.Authenticated(_) -> {
        ui.toggle_input(
          label: "Only your listings?",
          name: "filter_owned",
          is_checked: model.filter.only_owned,
          on_input: fn(is_checked) {
            UpdatedFilter(
              listing.SearchFilter(..model.filter, only_owned: is_checked),
            )
          },
        )
      }
      user.Unknown | user.Unauthenticated -> element.none()
    },
    case model.listings {
      option.Some(search_result) -> {
        h.div([], [
          keyed.ol(
            [],
            search_result.listings
              |> list.map(fn(listing) {
                #(
                  listing.id,
                  h.li([], [
                    ui.listing_card_view(
                      listing,
                      is_editable: shared
                        |> shared.get_user
                        |> option.map(fn(user) { user.id == listing.seller.id })
                        |> option.unwrap(False),
                    ),
                  ]),
                )
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
          "An error occurred while searching for listings. Please try again.",
        )
      }
    },
  ])
}
