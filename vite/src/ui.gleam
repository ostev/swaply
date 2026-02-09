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
import sketch/lustre/element/keyed
import tempo
import tempo/date
import tempo/datetime
import tempo/offset
import ui/colors
import ui/fonts
import ui/layout
import ui/styles

pub type ButtonRole {
  Regular
  Danger
}

pub fn button(role: ButtonRole, text: String, on_click: msg) -> Element(msg) {
  button_internal("button", role, text, on_click)
}

pub fn submit(role: ButtonRole, text: String, on_click: msg) -> Element(msg) {
  button_internal("submit", role, text, on_click)
}

fn button_internal(
  type_: String,
  role: ButtonRole,
  text: String,
  on_click: msg,
) -> Element(msg) {
  let #(bg_color, hover_color, text_color) = case role {
    Regular -> #(
      colors.primary_background,
      colors.primary_foreground,
      colors.black,
    )
    Danger -> #(colors.red, colors.red_light, "black")
  }

  h.button(
    css.class([
      css.color(text_color),
      css.background_color(bg_color),

      fonts.inter(),
      fonts.size_md(),

      css.border_style("solid"),
      css.border_color("black"),
      css.border_width(length.px(1)),
      css.border_radius(length.px(6)),

      css.padding_inline(length.px(10)),
      css.padding_block(length.px(6)),

      css.transition("box-shadow 0.3s"),
      css.box_shadow("3px 3px 5px " <> colors.button_box_shadow),
      css.hover([
        css.box_shadow("2px 2px 3px " <> colors.button_box_shadow),
      ]),
      css.active([
        css.box_shadow("0px 0px 2px " <> colors.button_box_shadow),
      ]),

      css.transition("background-color 0.3s, box-shadow 0.3s"),
      css.cursor("pointer"),

      css.hover([css.background_color(hover_color)]),
    ]),
    [a.type_(type_), e.on_click(on_click)],
    [h.text(text)],
  )
}

pub fn input(
  class: css.Class,
  type_ type_: String,
  name name: String,
  label label: String,
  value value: Option(String),
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) -> Element(msg) {
  h.div(
    css.class([css.compose(layout.column(layout.Start)), fonts.inter()]),
    [],
    [
      h.label(
        css.class([
          css.margin_bottom(length.em(0.3)),
        ]),
        [a.for(name)],
        [
          h.text(label),
        ],
      ),
      h.input(
        css.class([
          css.display("block"),

          css.padding(length.px(10)),
          css.background_color(colors.input_background),
          css.border_color(colors.black),
          css.border_style("solid"),
          css.border_width(length.px(1)),
          css.border_radius(length.px(6)),

          fonts.size_md(),

          styles.input_box_shadow(),

          css.placeholder([css.color(colors.placeholder_text)]),

          css.width(length.percent(100)),
          css.box_sizing("border-box"),
          css.text_align("start"),

          css.compose(class),
        ]),
        [
          a.type_(type_),
          a.name(name),
          a.id(name),
          a.value(value |> option.unwrap("")),
          a.classes([#("invalid", !is_valid)]),
          e.on_input(on_input),
        ],
      ),
    ],
  )
}

pub fn input_(
  type_ type_: String,
  name name: String,
  label label: String,
  value value: Option(String),
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) {
  input(css.class([]), type_, name, label, value, on_input, is_valid)
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
  h.div(
    css.class([
      css.compose(layout.row(layout.SpaceBetween)),
      css.gap(length.em(1.0)),
    ]),
    [],
    [
      h.label(css.class([css.display("block"), fonts.inter()]), [a.for(name)], [
        h.text(label),
      ]),
      h.input(
        css.class([
          css.display("block"),
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

          css.color(colors.black),

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
              "transform 0.4s "
              <> styles.energetic_hover_curve
              <> ", background-color 0.4s "
              <> styles.energetic_hover_curve
              <> ", box-shadow 0.4s "
              <> styles.energetic_hover_curve,
            ),
          ]),

          css.box_shadow("1px 1px 1px " <> colors.input_box_shadow <> " inset"),
          css.transition("box-shadow 0.4s " <> styles.energetic_hover_curve),

          css.hover([
            css.before([
              css.transform([
                transform.translate(length.em(0.1), length.percent(-50)),
              ]),
            ]),
          ]),

          css.checked([
            css.box_shadow(
              "2px 2px 2px " <> colors.input_box_shadow <> " inset",
            ),

            css.before([
              css.transform([
                transform.translate(length.em(1.0), length.percent(-50)),
              ]),

              css.background_color(colors.secondary),
              css.box_shadow("2px 2px 8px 2px " <> colors.input_box_shadow),
            ]),

            css.hover([
              css.before([
                css.transform([
                  transform.translate(length.em(0.95), length.percent(-50)),
                ]),
              ]),
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
    ],
  )
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
  let is_invalid =
    !string.is_empty(value)
    && value
    |> lenient_parse.to_float
    |> result.map(fn(value) {
      !{
        min <=. value
        && value <=. max
        && float.modulo(value, by: step)
        |> result.map(float.loosely_equals(_, with: 0.0, tolerating: 0.001))
        |> result.unwrap(False)
      }
    })
    |> result.unwrap(True)

  h.div(
    css.class([css.compose(layout.column(layout.Start)), fonts.inter()]),
    [],
    [
      h.label(
        css.class([
          css.margin_bottom(length.em(0.3)),
        ]),
        [a.for(name)],
        [
          h.text(label),
        ],
      ),
      h.input(
        css.class([
          css.display("block"),

          css.padding(length.px(10)),
          css.background_color(colors.input_background),
          css.border_color(case is_invalid {
            False -> colors.black
            True -> colors.red
          }),
          css.border_style("solid"),
          css.border_width(length.px(1)),
          css.border_radius(length.px(6)),

          fonts.size_md(),

          styles.input_box_shadow(),

          css.placeholder([css.color(colors.placeholder_text)]),

          css.width(length.percent(100)),
          css.box_sizing("border-box"),
          css.text_align("start"),
        ]),
        [
          a.type_("text"),
          a.name(name),
          a.id(name),
          a.value(value),
          a.min(float.to_string(min)),
          a.max(float.to_string(max)),
          a.step(float.to_string(step)),

          e.on_input(fn(text) {
            let trimmed_text = string.trim(text)

            let updated_value = case trimmed_text {
              "" -> option.None
              number -> lenient_parse.to_float(number) |> option.from_result
            }

            on_input(text, updated_value)
          }),
        ],
      ),
    ],
  )
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
  h.span(styles.tag(), [], [tag_content(text)])
}

fn tag_content(text: String) -> Element(msg) {
  h.div(css.class([css.compose(layout.row(layout.SpaceBetween))]), [], [
    phosphor.tag_regular([]),
    h.text(text),
  ])
}

fn tag_button(text: String, on_remove: fn(String) -> msg) -> Element(msg) {
  h.button(
    css.class([
      css.all("unset"),

      css.compose(styles.tag()),
      styles.input_box_shadow(),
      css.cursor("pointer"),

      // css.compose(styles.strikethrough_on_hover()),
      css.hover([
        css.text_decoration_line("line-through"),
        css.text_decoration_color(colors.black),
        css.text_decoration_thickness("0.1em"),
      ]),
    ]),
    [a.type_("button"), e.on_click(on_remove(text))],
    [tag_content(text)],
  )
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

  h.div(css.class([fonts.inter(), css.width(length.percent(100))]), [], [
    h.label(
      css.class([
        css.display("block"),
        css.margin_bottom(length.px(8)),
        fonts.inter(),
      ]),
      [a.for(name)],
      [h.text(label)],
    ),

    h.div(
      css.class([
        css.compose(layout.row(layout.Start)),
        css.gap(length.px(12)),

        css.background_color(colors.input_background),

        css.padding(length.px(10)),
        css.border_style("solid"),
        css.border_color(colors.black),
        css.border_width(length.px(1)),
        css.border_radius(length.px(12)),

        css.height(length.em(3.0)),
      ]),
      [],
      [
        h.input(
          css.class([
            css.compose(styles.tag()),

            styles.input_box_shadow(),

            css.placeholder([css.color(colors.placeholder_text)]),

            css.box_sizing("border-box"),
            css.text_align("start"),

            css.display("block"),
            css.width(length.percent(30)),
          ]),
          [
            a.type_("text"),
            a.name(name),
            a.id(name),
            a.value(value),
            a.placeholder("Tag..."),
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
          ],
        ),

        keyed.ul(
          css.class([
            css.all("unset"),

            css.compose(layout.row(layout.Start)),
            css.gap(length.px(4)),
            css.list_style("none"),

            css.overflow_x("auto"),
            css.height(length.percent(100)),
            css.width(length.percent(100)),
          ]),
          [],
          tags
            |> list.map(fn(tag) {
              #(tag, h.li_([], [tag_button(tag, on_remove_tag)]))
            }),
        ),
      ],
    ),
  ])
}

pub fn item_type_input(item_type: listing.ItemInput, name: String, on_input) {
  fieldset([
    title_input(
      css.class([
        css.max_width(length.percent(100)),
        css.width(length.percent(100)),
        css.font_size(length.px(25)),
      ]),
      name: "name",
      label: "Name",
      value: item_type.name,
      on_input: fn(value) {
        on_input(listing.ItemInput(..item_type, name: value))
      },
    ),

    h.div(
      css.class([
        css.compose(layout.row(layout.SpaceBetween)),
        css.gap(length.px(20)),
      ]),
      [],
      [
        number_input(
          name: name <> "_price",
          label: "Price (AUD)",
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
      ],
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

pub fn fieldset(children: List(Element(msg))) -> Element(msg) {
  h.fieldset(
    css.class([
      css.all("unset"),
      css.width(length.percent(100)),
      css.compose(layout.column(layout.Start)),
      css.gap(length.px(10)),
      // css.padding_block(length.px(20)),
    // css.border_top_style("solid"),
    // css.border_top_color("rgba(0, 0, 0, 0.37)"),
    // css.border_top_width(length.px(1)),
    ]),
    [],
    children,
  )
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

pub fn h2(text: String) -> Element(msg) {
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

pub fn h3(text: String) -> Element(msg) {
  h.h3(
    css.class([
      fonts.merriweather(),
      css.font_size(length.px(30)),
      css.font_weight("500"),
      css.margin(length.px(0)),

      css.margin_block_start(length.px(8)),
      css.margin_block_end(length.px(6)),

      css.text_align("center"),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}

pub fn title_input(
  class: css.Class,
  name name: String,
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  h.input(
    css.class([
      css.all("unset"),
      css.display("block"),

      css.padding(length.px(10)),
      css.background_color(colors.input_background),
      css.border_color(colors.black),
      css.border_style("solid"),
      css.border_width(length.px(1)),
      css.border_radius(length.px(6)),
      css.font_size(length.px(16)),

      css.transition("box-shadow 0.3s"),
      css.box_shadow("3px 3px 3px " <> colors.input_box_shadow),
      css.hover([
        css.box_shadow("1px 1px 3px " <> colors.input_box_shadow),
      ]),
      css.active([
        css.box_shadow("0px 0px 2px " <> colors.input_box_shadow),
      ]),

      css.placeholder([css.color(colors.placeholder_text)]),

      fonts.merriweather(),
      css.font_size(length.px(30)),
      css.text_align("center"),

      css.width(length.percent(100)),
      css.max_width(length.em(10.0)),
      css.box_sizing("border-box"),

      css.margin_bottom(length.px(8)),

      css.compose(class),
    ]),
    [
      a.value(value),
      a.placeholder(label <> "..."),
      e.on_input(on_input),

      a.aria_label(label),
      a.name(name),
    ],
  )
}
