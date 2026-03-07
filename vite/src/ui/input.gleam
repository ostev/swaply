import gleam/float
import gleam/int
import gleam/option.{type Option}
import gleam/result
import gleam/string
import lenient_parse
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/event as e
import sketch/css
import sketch/css/length.{type Length}
import sketch/css/transform
import sketch/lustre/element/html as h
import ui/colors
import ui/fonts
import ui/layout
import ui/styles

pub fn generic(
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
          case value {
            option.Some(valid_value) -> a.value(valid_value)
            option.None -> a.none()
          },
          a.classes([#("invalid", !is_valid)]),
          e.on_input(on_input),
        ],
      ),
    ],
  )
}

pub fn generic_(
  type_ type_: String,
  name name: String,
  label label: String,
  value value: Option(String),
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) {
  generic(css.class([]), type_, name, label, value, on_input, is_valid)
}

pub fn search(
  name name: String,
  label label: String,
  value value: String,
  placeholder placeholder: String,
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

      css.font_family("Inter, sans-serif"),

      css.width(length.percent(100)),
      css.box_sizing("border-box"),
      css.text_align("center"),
    ]),
    [
      a.value(value),
      a.placeholder(placeholder),
      e.debounce(e.on_input(on_input), 200),

      a.aria_label(label),
      a.name(name),
    ],
  )
}

pub fn toggle(
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

          css.cursor("pointer"),

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

pub fn number(
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
  height height: Length,
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) -> Element(msg) {
  h.div(
    css.class([
      css.compose(layout.column(layout.Start)),
      fonts.inter(),
      css.width(length.percent(100)),
    ]),
    [],
    [
      h.label(
        css.class([
          css.margin_bottom(length.em(0.3)),
        ]),
        [a.for(name)],
        [h.text(label)],
      ),
      h.textarea(
        css.class([
          css.display("block"),

          css.padding(length.px(10)),
          css.background_color(colors.input_background),
          css.border_color(case is_valid {
            True -> colors.black
            False -> colors.red
          }),
          css.border_style("solid"),
          css.border_width(length.px(1)),
          css.border_radius(length.px(6)),

          fonts.size_md(),
          fonts.inter(),

          styles.input_box_shadow(),

          css.placeholder([css.color(colors.placeholder_text)]),

          css.width(length.percent(100)),
          css.box_sizing("border-box"),
          css.text_align("start"),

          css.resize("none"),

          css.height(height),
          css.width(length.percent(100)),
        ]),
        [
          a.id(name),
          a.name(name),
          e.on_input(on_input),
        ],
        [h.text(value)],
      ),
    ],
  )
}

pub fn char_count(chars chars: Int, of of: Int) {
  h.span(
    css.class([
      css.compose(styles.text_italic()),
      fonts.inter(),
      fonts.size_md(),

      css.color(case chars > of {
        True -> colors.red
        False -> colors.black
      }),
    ]),
    [],
    [h.text(int.to_string(chars) <> "/" <> int.to_string(of))],
  )
}

pub fn title(
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
