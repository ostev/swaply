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
import lustre/attribute.{type Attribute} as a
import lustre/element.{type Element}
import lustre/event as e
import phosphor
import sequence
import sketch/css
import sketch/css/angle
import sketch/css/length.{type Length}
import sketch/css/transform
import sketch/lustre/element/html as h
import sketch/lustre/element/keyed
import tempo
import tempo/date
import tempo/datetime
import tempo/offset
import ui
import ui/colors
import ui/fonts
import ui/layout
import ui/styles
import ui/tags

pub fn card_view(
  listing: Listing,
  is_editable is_editable: Bool,
  on_click on_click: msg,
) {
  let width = css.width_("calc(100% - 24px)")
  let wrap = styles.wrap_3_lines()
  let detail = styles.detail()

  h.div(
    css.class([
      css.compose(layout.column(layout.Start)),
      css.compose(styles.card()),
      css.cursor("pointer"),
      css.padding(length.px(8)),
      css.padding_left(length.px(8 + 12)),
      css.padding_right(length.px(8 + 12)),

      css.margin_block(length.px(18)),

      css.compose(styles.rotate_hover(0.05)),
    ]),
    [e.on_click(on_click)],
    [
      h.h3(
        css.class([
          fonts.merriweather(),
          css.font_weight("450"),

          css.font_size(length.px(30)),
          css.margin_top(length.px(0)),
          css.margin_bottom(length.px(6)),

          width,
          wrap,
        ]),
        [],
        [
          h.a(
            css.class([
              css.color(colors.black),
              css.text_decoration("none"),
            ]),
            [a.href(listing.page_url(listing.id))],
            [
              h.text(listing.name),
            ],
          ),
        ],
      ),

      h.div(
        css.class([
          width,
        ]),
        [],
        [
          tags.tags(listing.tags),
        ],
      ),
      h.div(
        css.class([css.compose(layout.row(layout.SpaceBetween)), width]),
        [],
        [
          case string.trim(listing.location) {
            "" -> element.none()
            _ ->
              h.p(css.class([wrap, css.flex_grow(1), css.margin_("0")]), [], [
                location(listing.location),
              ])
          },
          h.p(
            css.class([
              detail,
              css.flex_grow(0),
              css.margin_("0"),
              css.compose(layout.row(layout.End)),
            ]),
            [],
            [
              datetime_view(listing.date),
            ],
          ),
        ],
      ),

      h.p(css.class([width, wrap, fonts.inter(), fonts.size_md()]), [], [
        h.text(listing.short_description),
      ]),

      case is_editable {
        True ->
          h.div(
            css.class([
              css.compose(layout.row(layout.End)),
              css.width(length.percent(100)),
            ]),
            [],
            [
              ui.link_button(
                role: ui.Primary,
                text: "Edit",
                to: "/listing/" <> uri.percent_encode(listing.id) <> "/edit",
              ),
            ],
          )
        False -> element.none()
      },
    ],
  )
}

pub fn tag(text: String) -> Element(msg) {
  h.span(styles.tag(), [], [tag_content(text)])
}

fn tag_content(text: String) -> Element(msg) {
  h.div(
    css.class([
      css.compose(layout.row(layout.SpaceBetween)),
      css.gap(length.px(4)),
    ]),
    [],
    [
      phosphor.tag_regular([]),
      h.text(text),
    ],
  )
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

pub fn item_type_input(item_type: listing.ItemInput, name: String, on_input) {
  ui.fieldset([
    ui.title_input(
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
        ui.number_input(
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
        ui.number_input(
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

pub fn location(text: String) {
  h.span(css.class([styles.detail()]), [], [
    phosphor.house_bold([a.style("font-size", "14px")]),
    h.text(text),
  ])
}

pub fn datetime_view(datetime: tempo.DateTime) -> Element(msg) {
  let date =
    datetime
    |> datetime.to_offset(offset.local())
  h.span_([], [
    phosphor.clock_bold([a.style("font-size", "14px")]),
    h.text(
      date
      |> datetime.format(tempo.Custom("h:mma YYYY-M-D")),
    ),
  ])
}
