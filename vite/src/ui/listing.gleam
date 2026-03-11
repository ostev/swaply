import gleam/float
import gleam/string
import gleam/uri
import listing.{type Listing}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/event as e
import phosphor
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import tempo
import tempo/datetime
import tempo/offset
import ui
import ui/button
import ui/colors
import ui/fonts
import ui/input
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

  let price = case listing.items {
    [item] -> "$" <> float.to_string(item.price)
    _ -> "Varies"
  }

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
      h.div(
        css.class([
          css.compose(layout.row(layout.SpaceBetween)),

          css.width(length.percent(100)),
        ]),
        [],
        [
          h.h3(
            css.class([
              fonts.merriweather(),
              css.font_weight("450"),

              css.font_size(length.px(30)),
              css.margin_top(length.px(0)),
              css.margin_bottom(length.px(6)),

              css.flex_grow(1),

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
              fonts.merriweather(),
              css.font_size(length.px(18)),
              css.font_weight("400"),
            ]),
            [],
            [
              h.span_([], [h.text(price)]),
            ],
          ),
        ],
      ),

      h.div(css.class([width, css.margin_bottom(length.px(4))]), [], [
        tags.tags(listing.tags),
      ]),
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
              button.link(
                role: button.Primary,
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

pub fn item_type_input(item_type: listing.ItemInput, name: String, on_input) {
  ui.fieldset([
    input.title(
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
        input.number(
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
        input.number(
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
