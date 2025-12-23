import api
import extra/decode as decode_extra
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json.{type Json}
import gleam/uri
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import rsvp
import tempo.{type DateTime}
import tempo/datetime

pub const api_prefix = api.prefix <> "/events"

pub type Event {
  Event(
    id: String,
    manager_id: String,
    is_published: Bool,
    name: String,
    date: DateTime,
    ticket_types: List(TicketType),
  )
}

pub type TicketType {
  TicketType(name: String, price: Float, allotted: Int)
}

pub fn ticket_type_to_json(ticket_type: TicketType) -> Json {
  let TicketType(name:, price:, allotted:) = ticket_type
  json.object([
    #("name", json.string(name)),
    #("price", json.float(price)),
    #("allotted", json.int(allotted)),
  ])
}

fn ticket_type_decoder() -> decode.Decoder(TicketType) {
  use name <- decode.field("name", decode.string)
  use price <- decode.field("price", decode.float)
  use allotted <- decode.field("allotted", decode.int)
  decode.success(TicketType(name:, price:, allotted:))
}

pub fn decoder() -> decode.Decoder(Event) {
  use id <- decode.field("id", decode.string)
  use manager_id <- decode.field("manager_id", decode.string)
  use is_published <- decode.field("is_published", decode.bool)
  use name <- decode.field("name", decode.string)
  use date <- decode.field("date", decode_extra.datetime())
  use ticket_types <- decode.field(
    "ticket_types",
    decode.list(ticket_type_decoder()),
  )

  decode.success(Event(
    id:,
    manager_id:,
    is_published:,
    name:,
    date:,
    ticket_types:,
  ))
}

pub fn encode(event: Event) -> Json {
  json.object([
    #("id", json.string(event.id)),
    #("manager_id", json.string(event.manager_id)),
    #("is_published", json.bool(event.is_published)),
    #("name", json.string(event.name)),
    #("date", json.string(event.date |> datetime.format(tempo.ISO8601Seconds))),
    #(
      "ticket_types",
      json.array(from: event.ticket_types, of: ticket_type_to_json),
    ),
  ])
}

pub fn event_url(id: String) -> String {
  api_prefix <> "/" <> id
}

pub fn get_event(
  id: String,
  handler: fn(Result(Event, rsvp.Error)) -> a,
) -> Effect(a) {
  let rsvp_handler = rsvp.expect_json(decoder(), handler)

  rsvp.get(event_url(id), rsvp_handler)
}

pub fn search_events(
  query: String,
  page: Int,
  handler: fn(Result(List(Event), rsvp.Error)) -> a,
) -> Effect(a) {
  let query_string =
    uri.query_to_string([#("q", query), #("p", int.to_string(page))])
  let url = api_prefix <> "/search?" <> query_string

  let decoder = decode.list(of: decoder())
  let rsvp_handler = rsvp.expect_json(decoder, handler)

  rsvp.get(url, rsvp_handler)
}

pub fn update_event(to updated_event: Event, with handler) {
  let json_string =
    updated_event
    |> encode
    |> json.to_string

  rsvp.send(
    request.new()
      |> request.set_path(event_url(updated_event.id))
      |> request.set_method(http.Patch)
      |> request.set_body(json_string)
      |> request.set_header("content-type", "application/json"),
    handler,
  )
}

pub fn get_user_events(handler) {
  let url = api_prefix <> "/managing"

  let decoder = decode.list(of: decoder())
  let rsvp_handler = rsvp.expect_json(decoder, handler)

  rsvp.get(url, rsvp_handler)
}
