import event.{type Event}
import gleam/int
import gleam/option.{type Option}
import gleam/uri
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import rsvp
import shared.{type Shared}
import tempo
import tempo/date
import tempo/datetime
import tempo/offset
import ui

pub type Model {
  Model(event: Option(Result(Event, rsvp.Error)))
}

pub fn init(event_id: String) -> #(Model, Effect(Msg)) {
  #(Model(event: option.None), event.get(event_id, EventReceived))
}

pub type Msg {
  EventReceived(Result(Event, rsvp.Error))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    EventReceived(event) -> #(Model(event: option.Some(event)), effect.none())
  }
}

fn view_event(event: Event) -> Element(Msg) {
  let date =
    event.date
    |> datetime.to_offset(offset.local())
  let day =
    date
    |> datetime.get_date
    |> date.get_day

  h.div([], [
    h.div([], [
      h.h2([], [h.text(event.name)]),
      ui.tags(event.tags),
      h.div([], [
        h.p([], [
          h.text(
            date
            |> datetime.format(tempo.Custom("h:mma on dddd")),
          ),
          h.text(
            " "
            <> int.to_string(day)
            <> case day {
              1 -> "st"
              2 -> "nd"
              3 -> "rd"
              _ -> "th"
            }
            <> " ",
          ),
          h.text(
            date
            |> datetime.format(tempo.Custom("MMMM YYYY")),
          ),
        ]),
        case event.location {
          "" -> element.none()
          _ -> h.p([], [h.text(event.location)])
        },
      ]),
      case event.is_published {
        False -> h.span([], [h.text("Private")])
        True -> element.none()
      },
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

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  h.div([], case model.event {
    option.Some(result) -> {
      case result {
        Ok(event) -> {
          [
            case shared.user {
              shared.Authenticated(_) -> {
                h.a(
                  [
                    a.href("/event/" <> uri.percent_encode(event.id) <> "/edit"),
                  ],
                  [h.text("Edit")],
                )
              }
              _ -> {
                element.none()
              }
            },
            view_event(event),
          ]
        }
        Error(error) -> {
          [
            h.p([], [
              case error {
                rsvp.HttpError(response) -> {
                  case response.status {
                    404 -> h.text("This event does not exist.")
                    _ ->
                      h.text(
                        "An error occurred while loading the event. Please try again.",
                      )
                  }
                }
                _ -> {
                  h.text(
                    "An error occurred while loading the event. Please try again.",
                  )
                }
              },
            ]),
          ]
        }
      }
    }
    option.None -> {
      [element.none()]
    }
  })
}
