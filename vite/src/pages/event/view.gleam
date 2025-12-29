import event.{type Event}
import extra/list as extra_list
import extra/time
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri.{type Uri}
import iv
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import modem
import pages/auth
import pages/auth/user.{type User}
import rsvp
import shared.{type Shared}
import tempo
import tempo/date
import tempo/datetime
import tempo/error as tempo_error
import tempo/offset
import tempo/time as tempo_time
import ui

pub type Model {
  Model(event: Option(Result(Event, rsvp.Error)))
}

pub fn init(event_id: String) -> #(Model, Effect(Msg)) {
  #(Model(event: option.None), event.get_event(event_id, EventReceived))
}

pub type Msg {
  EventReceived(Result(Event, rsvp.Error))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    _ -> #(model, effect.none())
  }
}

fn view_event(event: Event) -> Element(Msg) {
  h.div([], [
    h.div([], [
      h.h2([], [h.text(event.name)]),
      ui.tags(event.tags),
      case event.short_description {
        "" -> element.none()
        _ -> h.p([], [h.text(event.short_description)])
      },
    ]),

    h.div([], [
      case event.description {
        "" ->
          h.p([], [
            h.text("The manager of this event has provided no description."),
          ])
        _ -> h.p([], [h.text(event.description)])
      },
    ]),
  ])
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [
    case model.event {
      option.Some(result) -> {
        case result {
          Ok(event) -> {
            view_event(event)
          }
          Error(error) -> {
            h.p([], [
              h.text(
                "An error occurred while loading the event. Please try again.",
              ),
            ])
          }
        }
      }
      option.None -> {
        element.none()
      }
    },
  ])
}
