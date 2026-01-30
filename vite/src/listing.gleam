import api
import extra/decode as extra_decode
import extra/list as extra_list
import extra/rsvp as extra_rsvp
import gleam/bool
import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
import lenient_parse
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import rsvp
import tempo.{type DateTime}
import tempo/date
import tempo/datetime
import tempo/instant
import tempo/offset
import tempo/time

pub const api_prefix = api.prefix <> "/listings"

pub type Listing {
  Listing(
    id: String,
    short_description: String,
    description: String,
    location: String,
    seller: String,
    is_published: Bool,
    name: String,
    date: DateTime,
    tags: List(String),
    item_types: List(TicketType),
  )
}

pub type TicketType {
  TicketType(name: String, price: Float, allotted: Int)
}

pub fn item_type_to_json(item_type: TicketType) -> Json {
  let TicketType(name:, price:, allotted:) = item_type
  json.object([
    #("name", json.string(name)),
    #("price", json.float(price)),
    #("allotted", json.int(allotted)),
  ])
}

fn item_type_decoder() -> decode.Decoder(TicketType) {
  use name <- decode.field("name", decode.string)
  use price <- decode.field(
    "price",
    decode.one_of(decode.float, or: [
      decode.int
      |> decode.map(int.to_float),
    ]),
  )
  use allotted <- decode.field("allotted", decode.int)
  decode.success(TicketType(name:, price:, allotted:))
}

pub type TicketTypeInput {
  TicketTypeInput(name: String, price: String, allotted: String)
}

pub fn parse_item_type(item_type_input: TicketTypeInput) {
  use price <- result.try(lenient_parse.to_float(item_type_input.price))
  use allotted <- result.try(lenient_parse.to_int(item_type_input.allotted))

  Ok(TicketType(name: item_type_input.name, price:, allotted:))
}

pub fn decoder() -> decode.Decoder(Listing) {
  use id <- decode.field("id", decode.string)
  use seller <- decode.field("seller", decode.string)
  use is_published <- decode.field("is_published", decode.bool)
  use name <- decode.field("name", decode.string)
  use date <- decode.field("date", extra_decode.datetime())
  use item_types <- decode.field(
    "item_types",
    decode.list(of: item_type_decoder()),
  )
  use tags <- decode.field("tags", decode.list(of: decode.string))
  use short_description <- decode.field("short_description", decode.string)
  use description <- decode.field("description", decode.string)
  use location <- decode.field("location", decode.string)

  decode.success(Listing(
    id:,
    seller:,
    is_published:,
    name:,
    date:,
    item_types:,
    tags:,
    short_description:,
    description:,
    location:,
  ))
}

pub fn encode(listing: Listing) -> Json {
  json.object([
    #("id", json.string(listing.id)),
    #("seller", json.string(listing.seller)),
    #("is_published", json.bool(listing.is_published)),
    #("name", json.string(listing.name)),
    #(
      "date",
      json.string(listing.date |> datetime.format(tempo.ISO8601Seconds)),
    ),
    #("item_types", json.array(from: listing.item_types, of: item_type_to_json)),
  ])
}

pub fn url(id: String) -> String {
  api_prefix <> "/" <> uri.percent_encode(id)
}

pub fn get(
  id: String,
  handler: fn(Result(Listing, rsvp.Error)) -> a,
) -> Effect(a) {
  let rsvp_handler = rsvp.expect_json(decoder(), handler)

  rsvp.get(url(id), rsvp_handler)
}

pub fn delete(id: String, handler: fn(Result(Nil, rsvp.Error)) -> msg) {
  extra_rsvp.send(
    body: json.object([]),
    to: url(id),
    with: http.Delete,
    handler: rsvp.expect_ok_response(fn(result) {
      result
      |> result.replace(Nil)
      |> handler
    }),
  )
}

pub type SearchResults {
  ListingSearchResults(
    listings: List(Listing),
    number_of_pages: Int,
    timestamp: tempo.Instant,
  )
}

pub type SearchFilter {
  SearchFilter(
    only_owned: Bool,
    start_date: Option(tempo.Date),
    end_date: Option(tempo.Date),
  )
}

pub fn search(
  query query: String,
  page page: Int,
  filter filter: SearchFilter,
  timestamp timestamp: tempo.Instant,
  handler handler: fn(Result(SearchResults, rsvp.Error)) -> msg,
) -> Effect(msg) {
  let query_string =
    uri.query_to_string([
      #("q", query),
      #("p", int.to_string(page)),
      #("filter_owned", bool.to_string(filter.only_owned) |> string.lowercase),
      ..{
        [
          filter.start_date
            |> option.map(fn(date) {
              #(
                "start_date",
                datetime.new(date, time.start_of_day, offset.local())
                  |> datetime.format(tempo.ISO8601Seconds),
              )
            }),
          filter.end_date
            |> option.map(fn(date) {
              #(
                "end_date",
                datetime.new(date, time.start_of_day, offset.local())
                  |> datetime.format(tempo.ISO8601Seconds),
              )
            }),
        ]
        |> list.filter_map(option.to_result(_, Nil))
      }
    ])
  let url = api_prefix <> "/search?" <> query_string

  let decoder = {
    use listings <- decode.field("listings", decode.list(of: decoder()))
    use number_of_pages <- decode.field("number_of_pages", decode.int)

    decode.success(#(listings, number_of_pages))
  }

  let rsvp_handler =
    rsvp.expect_json(decoder, fn(listings_result) {
      listings_result
      |> result.map(fn(listings_with_pages) {
        case listings_with_pages {
          #(listings, number_of_pages) ->
            ListingSearchResults(listings:, number_of_pages:, timestamp:)
        }
      })
      |> handler
    })

  rsvp.get(url, rsvp_handler)
}

pub fn get_user_listings(handler) {
  let url = api_prefix <> "/managing"

  let decoder = decode.list(of: decoder())
  let rsvp_handler = rsvp.expect_json(decoder, handler)

  rsvp.get(url, rsvp_handler)
}
