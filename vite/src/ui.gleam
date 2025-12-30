import event.{type Event}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri
import lenient_parse
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import tempo
import tempo/date
import tempo/datetime
import tempo/offset

pub fn input(
  type_ type_: String,
  name name: String,
  label label: String,
  value value: Option(String),
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) -> Element(msg) {
  h.div([], [
    h.label([a.for(name)], [h.text(label)]),
    h.input([
      a.type_(type_),
      a.name(name),
      a.id(name),
      a.value(value |> option.unwrap("")),
      a.classes([#("invalid", !is_valid)]),
      e.on_input(on_input),
    ]),
  ])
}

pub fn toggle_input(
  label label: String,
  name name: String,
  is_checked is_checked: Bool,
  on_input on_input: fn(Bool) -> msg,
) -> Element(msg) {
  h.div([], [
    h.label([a.for(name)], [h.text(label)]),
    h.input([
      a.type_("checkbox"),
      a.name(name),
      a.id(name),
      a.checked(is_checked),
      e.on_check(on_input),
    ]),
  ])
}

pub fn number_input(
  name name: String,
  label label: String,
  value value: String,
  on_input on_input: fn(String, Option(Float)) -> msg,
  min min: Float,
  max max: Float,
  step step: Float,
) -> Element(msg) {
  h.div([], [
    h.label([a.for(name)], [h.text(label)]),
    h.input([
      a.type_("text"),
      a.name(name),
      a.id(name),
      a.value(value),
      a.min(float.to_string(min)),
      a.max(float.to_string(max)),
      a.step(float.to_string(step)),
      a.classes([
        #(
          "invalid",
          value
            |> lenient_parse.to_float
            |> result.map(fn(value) {
              !{
                min <=. value
                && value <=. max
                && float.modulo(value, by: step)
                |> result.map(float.loosely_equals(
                  _,
                  with: 0.0,
                  tolerating: 0.001,
                ))
                |> result.unwrap(False)
              }
            })
            |> result.unwrap(True),
        ),
      ]),
      e.on_input(fn(text) {
        let trimmed_text = string.trim(text)

        let updated_value = case trimmed_text {
          "" -> option.None
          number -> lenient_parse.to_float(number) |> option.from_result
        }

        on_input(text, updated_value)
      }),
    ]),
  ])
}

pub fn textarea(
  name name: String,
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) -> Element(msg) {
  h.div([], [
    h.label([a.for(name)], [h.text(label)]),
    h.textarea(
      [
        a.name(name),
        a.id(name),
        a.classes([#("invalid", !is_valid)]),
        e.on_input(on_input),
      ],
      value,
    ),
  ])
}

pub fn tag(text: String) -> Element(msg) {
  h.span([], [h.text(text)])
}

fn tag_button(text: String, on_remove: fn(String) -> msg) -> Element(msg) {
  h.button([a.type_("button"), e.on_click(on_remove(text))], [tag(text)])
}

pub fn sort_tags(unsorted: Set(String)) -> List(String) {
  unsorted |> set.to_list |> list.sort(string.compare)
}

pub fn tags_input(
  label label: String,
  name name: String,
  sorted_tags tags: List(String),
  value value: String,
  on_update_value on_update_value: fn(String) -> msg,
  on_create_tags on_create_tags: fn(List(String)) -> msg,
  on_remove_tag on_remove_tag: fn(String) -> msg,
) -> Element(msg) {
  let create_tags = fn(new_tags) {
    let untrimmed_tags =
      new_tags
      |> string.split(",")

    untrimmed_tags
    |> list.map(string.trim)
    |> list.filter(fn(tag) { tag != "" })
    |> on_create_tags
  }

  h.div([], [
    h.label([a.for(name)], [h.text(label)]),
    h.span(
      [],
      tags
        |> list.map(tag_button(_, on_remove_tag)),
    ),
    h.div([], [
      h.input([
        a.type_("text"),
        a.name(name),
        a.id(name),
        a.value(value),
        e.on_input(fn(new_tags) {
          case new_tags |> string.trim_end() |> string.ends_with(",") {
            True -> {
              create_tags(new_tags)
            }
            False -> {
              on_update_value(new_tags)
            }
          }
        }),
        e.advanced("keyup", {
          use key <- decode.field("key", decode.string)

          decode.success(case key {
            "Enter" -> {
              e.handler(
                dispatch: create_tags(value),
                prevent_default: True,
                stop_propagation: False,
              )
            }
            _ -> {
              e.handler(
                dispatch: on_create_tags([]),
                prevent_default: True,
                stop_propagation: False,
              )
            }
          })
        }),
      ]),
    ]),
  ])
}

pub fn ticket_type_input(
  ticket_type: event.TicketTypeInput,
  name: String,
  on_input,
) {
  element.fragment([
    input(
      type_: "text",
      name: name <> "_name",
      label: "Name",
      value: option.Some(ticket_type.name),
      on_input: fn(name) {
        on_input(event.TicketTypeInput(..ticket_type, name:))
      },
      is_valid: string.length(ticket_type.name) > 0,
    ),
    number_input(
      name: name <> "_price",
      label: "Price",
      value: ticket_type.price,
      on_input: fn(value, _) {
        on_input(event.TicketTypeInput(..ticket_type, price: value))
      },
      min: 0.0,
      max: 1_000_000.0,
      step: 0.01,
    ),
    number_input(
      name: name <> "_allotted",
      label: "Allotted",
      value: ticket_type.allotted,
      on_input: fn(value, _) {
        on_input(event.TicketTypeInput(..ticket_type, allotted: value))
      },
      min: 1.0,
      max: 1_000_000.0,
      step: 1.0,
    ),
  ])
}

pub fn tags(tags: List(String)) {
  h.ul(
    [],
    tags
      |> list.map(fn(text) { h.li([], [tag(text)]) }),
  )
}

pub fn event_card_view(event: Event, is_editable is_editable: Bool) {
  h.div([], [
    h.h3([], [
      h.a([a.href("/event/" <> uri.percent_encode(event.id))], [
        h.text(event.name),
      ]),
    ]),
    tags(event.tags),
    h.p([], [h.text(event.location)]),
    h.p([], [datetime_view(event.date)]),

    case is_editable {
      True ->
        h.a(
          [
            a.href("/event/" <> uri.percent_encode(event.id) <> "/edit"),
          ],
          [h.text("Edit")],
        )
      False -> element.none()
    },

    h.p([], [h.text(event.short_description)]),
  ])
}

pub fn datetime_view(datetime: tempo.DateTime) -> Element(msg) {
  let date =
    datetime
    |> datetime.to_offset(offset.local())
  let day =
    datetime
    |> datetime.get_date
    |> date.get_day

  h.span([], [
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
  ])
}
