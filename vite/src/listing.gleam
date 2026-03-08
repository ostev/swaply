import api
import extra/decode as extra_decode
import gleam/bool
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
import lenient_parse
import lustre/effect.{type Effect}
import rsvp
import search
import seller.{type Seller}
import tempo.{type DateTime}
import tempo/datetime
import tempo/offset
import tempo/time

pub const api_root = "/listings"

pub type Listing {
  Listing(
    id: String,
    short_description: String,
    description: String,
    location: String,
    seller: Seller,
    is_published: Bool,
    name: String,
    date: DateTime,
    tags: List(String),
    items: List(Item),
  )
}

pub type Item {
  TicketType(name: String, price: Float, quantity: Int)
}

pub fn item_type_to_json(item_type: Item) -> Json {
  let TicketType(name:, price:, quantity:) = item_type
  json.object([
    #("name", json.string(name)),
    #("price", json.float(price)),
    #("quantity", json.int(quantity)),
  ])
}

fn item_decoder() -> decode.Decoder(Item) {
  use name <- decode.field("name", decode.string)
  use price <- decode.field(
    "price",
    decode.one_of(decode.float, or: [
      decode.int
      |> decode.map(int.to_float),
    ]),
  )
  use quantity <- decode.field("quantity", decode.int)
  decode.success(TicketType(name:, price:, quantity:))
}

pub type ItemInput {
  ItemInput(name: String, price: String, quantity: String)
}

pub fn parse_item_type(item_type_input: ItemInput) {
  use price <- result.try(lenient_parse.to_float(item_type_input.price))
  use quantity <- result.try(lenient_parse.to_int(item_type_input.quantity))

  Ok(TicketType(name: item_type_input.name, price:, quantity:))
}

pub fn decoder() -> decode.Decoder(Listing) {
  use id <- decode.field("id", decode.string)
  use seller <- decode.field("seller", seller.decoder())
  use is_published <- decode.field("is_published", decode.bool)
  use name <- decode.field("name", decode.string)
  use date <- decode.field("date", extra_decode.datetime())
  use items <- decode.field("items", decode.list(of: item_decoder()))
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
    items:,
    tags:,
    short_description:,
    description:,
    location:,
  ))
}

pub fn api_url(id: String) -> String {
  api_root <> "/" <> uri.percent_encode(id)
}

pub fn page_url(id: String) -> String {
  "/listing/" <> uri.percent_encode(id)
}

pub fn get(
  id: String,
  handler: fn(Result(Listing, rsvp.Error)) -> a,
) -> Effect(a) {
  let rsvp_handler = rsvp.expect_json(decoder(), handler)

  api.get(api_url(id), rsvp_handler)
}

pub fn delete(
  id: String,
  handler: fn(Result(Nil, rsvp.Error)) -> msg,
  with_token csrf_token: String,
) {
  api.send(
    body: json.object([]),
    to: api_url(id),
    with: http.Delete,
    handler: rsvp.expect_ok_response(fn(result) {
      result
      |> result.replace(Nil)
      |> handler
    }),
    with_token: csrf_token,
  )
}

pub type SearchFilter {
  SearchFilter(only_owned: Bool)
}

pub fn search(
  query query: String,
  page page: Int,
  filter filter: SearchFilter,
  timestamp timestamp: tempo.Instant,
  handler handler: fn(Result(search.Results(Listing), rsvp.Error)) -> msg,
) -> Effect(msg) {
  let query_string =
    uri.query_to_string([
      #("q", query),
      #("p", int.to_string(page)),
      #("filter_owned", bool.to_string(filter.only_owned) |> string.lowercase),
    ])
  let url = api_root <> "/search?" <> query_string

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
            search.Results(values: listings, number_of_pages:, timestamp:)
        }
      })
      |> handler
    })

  api.get(url, rsvp_handler)
}
