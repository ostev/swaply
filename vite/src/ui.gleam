import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri
import lenient_parse
import listing.{type Listing}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/event as e
import phosphor
import sequence
import sketch/css
import sketch/css/length
import sketch/css/transform
import sketch/lustre/element/html as h
import tempo
import tempo/date
import tempo/datetime
import tempo/offset
import ui/colors
import ui/fonts
import ui/styles

pub fn input(
  type_ type_: String,
  name name: String,
  label label: String,
  value value: Option(String),
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) -> Element(msg) {
  h.div_([], [
    h.label_([a.for(name)], [h.text(label)]),
    h.input_([
      a.type_(type_),
      a.name(name),
      a.id(name),
      a.value(value |> option.unwrap("")),
      a.classes([#("invalid", !is_valid)]),
      e.on_input(on_input),
    ]),
  ])
}

pub fn search_input(
  name name: String,
  label label: String,
  value value: Option(String),
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  h.div_([], [
    h.label_([a.for(name)], [h.text(label)]),
    h.input_([
      a.type_("text"),
      a.name(name),
      a.id(name),
      a.value(value |> option.unwrap("")),
      e.debounce(e.on_input(on_input), 100),
    ]),
  ])
}

pub fn toggle_input(
  label label: String,
  name name: String,
  is_checked is_checked: Bool,
  on_input on_input: fn(Bool) -> msg,
) -> Element(msg) {
  h.div_([], [
    h.label_([a.for(name)], [h.text(label)]),
    h.input(
      css.class([
        css.appearance("none"),
        css.position("relative"),
        css.font_size_("inherit"),

        css.width(length.em(2.3)),
        css.height(length.em(1.3)),

        css.box_sizing("content-box"),
        css.border_width(length.px(1)),
        css.border_style("solid"),
        css.border_color(colors.black),
        css.border_radius(length.em(1.0)),
        css.vertical_align("text-bottom"),

        css.margin_("auto"),
        css.color("inherit"),

        css.before([
          css.property("content", "\"\""),
          css.position("absolute"),
          css.top(length.percent(50)),
          css.left(length.percent(0)),

          css.transform([
            transform.translate(length.percent(0), length.percent(-50)),
          ]),
          css.box_sizing("border-box"),
          css.width(length.em(1.0)),
          css.height(length.em(1.0)),

          css.margin_("0 0.15em"),
          css.border_width(length.px(1)),
          css.border_style("solid"),
          css.border_radius(length.percent(50)),
          css.background_color(colors.black),

          css.transition(
            "transform 0.5s "
            <> styles.energetic_hover_curve
            <> ", background-color 0.5s "
            <> styles.energetic_hover_curve
            <> ", box-shadow 0.5s "
            <> styles.energetic_hover_curve,
          ),
        ]),

        css.box_shadow("1px 1px 1px rgba(41, 34, 49, 0.2) inset"),
        css.transition("box-shadow 0.5s " <> styles.energetic_hover_curve),

        css.checked([
          css.box_shadow("2px 2px 2px rgba(41, 34, 49, 0.2) inset"),

          css.before([
            css.transform([
              transform.translate(length.em(1.0), length.percent(-50)),
            ]),

            css.background_color(colors.secondary),

            css.box_shadow("2px 2px 8px 2px rgba(41, 34, 49, 0.2)"),
          ]),
        ]),
      ]),
      [
        a.type_("checkbox"),
        a.role("switch"),
        a.name(name),
        a.id(name),
        a.checked(is_checked),
        e.on_check(on_input),
      ],
    ),
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
  h.div_([], [
    h.label_([a.for(name)], [h.text(label)]),
    h.input_([
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
  h.div_([], [
    h.label_([a.for(name)], [h.text(label)]),
    h.textarea_(
      [
        a.name(name),
        a.id(name),
        a.classes([#("invalid", !is_valid)]),
        e.on_input(on_input),
      ],
      [h.text(value)],
    ),
  ])
}

pub fn tag(text: String) -> Element(msg) {
  h.span_([], [h.text(text)])
}

fn tag_button(text: String, on_remove: fn(String) -> msg) -> Element(msg) {
  h.button_([a.type_("button"), e.on_click(on_remove(text))], [tag(text)])
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

  h.div_([], [
    h.label_([a.for(name)], [h.text(label)]),
    h.span_(
      [],
      tags
        |> list.map(tag_button(_, on_remove_tag)),
    ),
    h.div_([], [
      h.input_([
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

pub fn item_type_input(item_type: listing.ItemInput, name: String, on_input) {
  element.fragment([
    input(
      type_: "text",
      name: name <> "_name",
      label: "Name",
      value: option.Some(item_type.name),
      on_input: fn(name) { on_input(listing.ItemInput(..item_type, name:)) },
      is_valid: string.length(item_type.name) > 0,
    ),
    number_input(
      name: name <> "_price",
      label: "Price",
      value: item_type.price,
      on_input: fn(value, _) {
        on_input(listing.ItemInput(..item_type, price: value))
      },
      min: 0.0,
      max: 1_000_000.0,
      step: 0.01,
    ),
    number_input(
      name: name <> "_quantity",
      label: "Quantity",
      value: item_type.quantity,
      on_input: fn(value, _) {
        on_input(listing.ItemInput(..item_type, quantity: value))
      },
      min: 1.0,
      max: 1_000_000.0,
      step: 1.0,
    ),
  ])
}

pub fn tags(tags: List(String)) {
  h.ul_(
    [],
    tags
      |> list.map(fn(text) { h.li_([], [tag(text)]) }),
  )
}

pub fn listing_card_view(listing: Listing, is_editable is_editable: Bool) {
  h.div_([], [
    h.h3_([], [
      h.a_([a.href("/listing/" <> uri.percent_encode(listing.id))], [
        h.text(listing.name),
      ]),
    ]),
    tags(listing.tags),
    h.p_([], [h.text(listing.location)]),
    h.p_([], [datetime_view(listing.date)]),

    case is_editable {
      True ->
        h.a_(
          [
            a.href("/listing/" <> uri.percent_encode(listing.id) <> "/edit"),
          ],
          [h.text("Edit")],
        )
      False -> element.none()
    },

    h.p_([], [h.text(listing.short_description)]),
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

  h.span_([], [
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

pub fn icon_button(attributes: List(a.Attribute(msg)), icon: Element(msg)) {
  h.button_(attributes, [icon])
}

pub fn page_control(
  page page: Int,
  of total_pages: Int,
  with change_page: fn(Int) -> msg,
) {
  let page_buttons =
    sequence.new(fn(index) {
      Ok(
        h.li_([], [
          h.button_([e.on_click(change_page(index))], [
            h.text(int.to_string(index + 1)),
          ]),
        ]),
      )
    })
    |> sequence.limit(total_pages)
    |> sequence.window(center: page, size: 6)
    |> sequence.generate

  h.div_([], [
    icon_button(
      [e.on_click(change_page(page - 1)), a.disabled(page <= 0)],
      phosphor.arrow_left_regular([]),
    ),
    h.ol_([], page_buttons),
    icon_button(
      [e.on_click(change_page(page + 1)), a.disabled(page >= total_pages)],
      phosphor.arrow_right_regular([]),
    ),
  ])
}

pub fn h1(text: String) {
  h.h1(
    css.class([
      fonts.merriweather(),
      css.font_size(length.px(48)),
      css.font_weight("500"),
      css.margin(length.px(0)),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}

pub fn h2(text: String) -> Element(a) {
  h.h2(
    css.class([
      fonts.merriweather(),
      css.font_size(length.px(48)),
      css.font_weight("500"),
      css.margin(length.px(0)),
      css.margin_block_end(length.px(10)),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}
