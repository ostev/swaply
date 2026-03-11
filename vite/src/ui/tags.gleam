import gleam/dynamic/decode
import gleam/list
import gleam/set.{type Set}
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/event as e
import phosphor
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import sketch/lustre/element/keyed
import ui/button.{button}
import ui/colors
import ui/fonts
import ui/layout
import ui/styles

/// Sort a set of tags alphabetically.
pub fn sort(unsorted: Set(String)) -> List(String) {
  unsorted |> set.to_list |> list.sort(string.compare)
}

/// Displays a list of sorted tags.
pub fn tags(tags: List(String)) {
  keyed.ul(
    css.class([
      css.compose(layout.row(layout.Start)),
      css.gap(length.px(4)),
      css.list_style("none"),
      css.margin_("0"),
      css.padding_("0"),

      css.width(length.percent(100)),
      css.overflow("auto"),
    ]),
    [],
    tags
      |> list.map(fn(text) {
        #(text, h.li(styles.tag(), [], [tag_content(text)]))
      }),
  )
}

/// Displays a tag for a listing
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

/// An editable list of tags.
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

        button(button.Primary, "Add", create_tags(value)),
      ],
    ),
  ])
}

/// A button with tag styling. Used for deletion.
fn tag_button(text: String, on_remove: fn(String) -> msg) -> Element(msg) {
  h.button(
    css.class([
      css.all("unset"),

      css.compose(styles.tag()),
      styles.input_box_shadow(),
      css.cursor("pointer"),

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
