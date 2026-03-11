import gleam/int
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/event as e
import phosphor
import sequence
import sketch/css
import sketch/css/angle
import sketch/css/length
import sketch/css/transform
import sketch/lustre/element/html as h
import ui/button.{button}
import ui/colors
import ui/fonts
import ui/layout
import ui/styles

/// A paginator control
pub fn paginator(
  page page: Int,
  of total_pages: Int,
  with change_page: fn(Int) -> msg,
) {
  let li_class =
    css.class([
      css.margin_("0"),
      css.padding_("0"),
      css.compose(styles.rotate_hover(-20.0)),
    ])
  let page_buttons =
    sequence.new(fn(index) {
      Ok(
        h.li(li_class, [], [
          button(
            case index == page {
              True -> button.Secondary
              False -> button.Primary
            },
            int.to_string(index + 1),
            change_page(index),
          ),
        ]),
      )
    })
    |> sequence.limit(total_pages)
    |> sequence.window(center: page, size: 6)
    |> sequence.generate

  let is_left_disabled = page <= 0
  let is_right_disabled = page >= total_pages

  h.div(
    css.class([css.compose(layout.row(layout.Center)), css.gap(length.px(24))]),
    [],
    [
      button.icon(
        css.class([
          css.compose(styles.rotate_hover(-20.0)),
          css.active([css.transform([transform.rotate(angle.deg(10.0))])]),

          case is_left_disabled {
            True -> css.cursor("not-allowed")
            False -> css.none()
          },
        ]),
        [e.on_click(change_page(page - 1)), a.disabled(is_left_disabled)],
        "Previous results page",
        phosphor.arrow_left_bold([a.style("font-size", "24px")]),
      ),
      h.ol(
        css.class([
          css.list_style("none"),
          css.margin_("0"),
          css.padding_("0"),

          css.compose(layout.row(layout.SpaceEvenly)),

          css.gap(length.px(12)),
        ]),
        [],
        page_buttons,
      ),
      button.icon(
        css.class([
          css.compose(styles.rotate_hover(20.0)),
          css.active([css.transform([transform.rotate(angle.deg(-10.0))])]),

          case is_right_disabled {
            True -> css.cursor("not-allowed")
            False -> css.none()
          },
        ]),
        [e.on_click(change_page(page + 1)), a.disabled(page >= total_pages)],
        "Next results page",
        phosphor.arrow_right_bold([a.style("font-size", "24px")]),
      ),
    ],
  )
}

/// Represents a fieldset within a form
pub fn fieldset(children: List(Element(msg))) -> Element(msg) {
  h.fieldset(
    css.class([
      css.all("unset"),
      css.width(length.percent(100)),
      css.compose(layout.column(layout.Start)),
      css.gap(length.px(10)),
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

pub fn h2_(text: String) -> Element(msg) {
  h2(css.class([]), text)
}

pub fn h2(class: css.Class, text: String) -> Element(msg) {
  h.h2(
    css.class([
      fonts.merriweather(),
      css.font_size(length.px(48)),
      css.font_weight("500"),
      css.margin(length.px(0)),
      css.margin_block_end(length.px(10)),

      css.compose(class),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}

pub fn h3_(text: String) -> Element(msg) {
  h3(css.class([]), text)
}

pub fn h3(class: css.Class, text: String) -> Element(msg) {
  h.h3(
    css.class([
      fonts.merriweather(),
      css.font_size(length.px(30)),
      css.font_weight("500"),
      css.margin(length.px(0)),

      css.margin_block_start(length.px(8)),
      css.margin_block_end(length.px(6)),

      css.compose(class),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}

pub fn h4_(text: String) -> Element(msg) {
  h4(css.class([]), text)
}

pub fn h4(class: css.Class, text: String) -> Element(msg) {
  h.h4(
    css.class([
      fonts.merriweather(),
      css.font_size(length.px(28)),
      css.font_weight("500"),
      css.margin(length.px(0)),

      css.margin_block_start(length.px(8)),
      css.margin_block_end(length.px(6)),

      css.compose(class),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}

pub type PanelRole {
  ErrorPanel
  InfoPanel
}

pub fn panel(role: PanelRole, is_visible: Bool, text: String) {
  h.div(
    css.class([
      css.min_height(length.em(1.5)),
      css.width(length.percent(100)),
      css.margin_block(length.px(8)),

      css.max_width(length.rem(30.0)),
    ]),
    [],
    case is_visible {
      False -> []
      True -> [
        h.p(
          css.class([
            fonts.inter(),
            fonts.size_md(),
            css.color(colors.black),

            css.border_color(case role {
              ErrorPanel -> colors.red
              InfoPanel -> colors.primary_background
            }),
            css.border_style("solid"),
            css.border_width(length.px(1)),
            css.border_radius(length.px(6)),

            css.font_weight("500"),
            css.margin(length.px(0)),
            css.padding(length.px(8)),
            css.background_color(case role {
              ErrorPanel -> colors.red_light
              InfoPanel -> colors.primary_foreground
            }),
          ]),
          [],
          [h.text(text)],
        ),
      ]
    },
  )
}

pub fn labelled_pair(label: String, text: String) {
  h.p(
    css.class([
      fonts.inter(),
      fonts.size_md(),
      css.margin_("0"),
      css.margin_bottom(length.px(4)),
    ]),
    [],
    [
      h.span(styles.text_bold(), [], [h.text(label <> ": ")]),
      h.text(text),
    ],
  )
}
