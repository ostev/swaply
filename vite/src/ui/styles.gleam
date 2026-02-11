import gleam/int
import sketch/css
import sketch/css/angle
import sketch/css/length
import sketch/css/transform
import ui/colors
import ui/fonts
import ui/layout

pub fn padding_sm() {
  css.padding(length.px(4))
}

pub fn padding_md() {
  css.padding(length.px(8))
}

pub fn padding_lg() {
  css.padding(length.px(12))
}

// Generated using https://easingwizard.com/
pub const energetic_hover_curve = "linear(0, 0.002 0.5%, 0.009 1%, 0.02 1.5%, 0.034 2%, 0.052 2.5%, 0.078 3.1%, 0.107 3.7%, 0.14 4.3%, 0.202 5.3%, 0.276 6.4%, 0.591 10.7%, 0.717 12.5%, 0.781 13.5%, 0.835 14.4%, 0.885 15.3%, 0.931 16.2%, 0.972 17.1%, 1.009 18%, 1.041 18.9%, 1.072 19.9%, 1.095 20.8%, 1.116 21.8%, 1.131 22.7%, 1.143 23.7%, 1.153 24.9%, 1.157 26.2%, 1.155 27.6%, 1.148 29.1%, 1.139 30.4%, 1.125 31.9%, 1.049 38.6%, 1.031 40.4%, 1.017 42%, 1.003 43.9%, 0.992 45.8%, 0.983 47.8%, 0.978 49.8%, 0.975 52.5%, 0.977 55.6%, 0.997 68.1%, 1.003 75.1%, 1.004 81.7%, 1)"

pub fn rotate_hover(amount) {
  css.class([
    css.transition("transform 0.3s " <> energetic_hover_curve),
    css.hover([css.transform([transform.rotate(angle.deg(amount))])]),
  ])
}

pub fn interactive_box_shadow() {
  css.class([
    css.transition("box-shadow 0.2s ease-in"),

    css.box_shadow("2px 2px 2px " <> colors.input_box_shadow),
    css.hover([
      css.box_shadow("1px 1px 2px " <> colors.input_box_shadow),
    ]),
    css.active([
      css.box_shadow("0px 0px 2px " <> colors.input_box_shadow),
    ]),
  ])
}

pub fn card() {
  css.class([
    css.padding(length.px(10)),
    css.background_color(colors.four),
    css.border_radius(length.px(10)),

    css.compose(interactive_box_shadow()),
  ])
}

pub fn input_box_shadow() -> css.Style {
  css.compose(
    css.class([
      css.transition("box-shadow 0.3s"),
      css.box_shadow("3px 3px 3px " <> colors.input_box_shadow),
      css.hover([
        css.box_shadow("1px 1px 3px " <> colors.input_box_shadow),
      ]),
      css.active([
        css.box_shadow("0px 0px 2px " <> colors.input_box_shadow),
      ]),
    ]),
  )
}

fn strikethrough_background(completion: Int) {
  css.background(
    "linear-gradient("
    <> colors.black
    <> " 0 0) no-repeat 0 60% / "
    <> int.to_string(completion)
    <> "% .1em, currentcolor",
  )
}

pub fn strikethrough_on_hover() {
  css.class([
    strikethrough_background(0),
    css.background_clip("border-box, text"),
    css.property("-webkit-text-fill-color", "transparent"),
    css.transition("background-size .4s " <> energetic_hover_curve),
    css.isolation("isolate"),

    css.hover([
      strikethrough_background(100),
    ]),
  ])
}

pub fn tag() {
  css.class([
    css.padding(length.px(4)),

    fonts.inter(),
    css.font_size(length.px(14)),

    css.border_style("solid"),
    css.border_color(colors.black),
    css.border_width(length.px(1)),
    css.border_radius(length.px(10)),

    css.width_("fit-content"),
    css.color(colors.black),
  ])
}

pub fn focus_outline() {
  css.compose(
    css.class([
      css.focus([
        css.outline_style("solid"),
        css.outline_width("2px"),
        css.outline_color(colors.primary_background),
      ]),
    ]),
  )
}

pub fn detail() {
  css.compose(
    css.class([
      fonts.inter(),
      fonts.size_md(),
      css.font_weight("350"),
      css.font_style("italic"),

      css.margin_top(length.px(10)),
      css.margin_bottom(length.px(0)),
    ]),
  )
}

pub fn wrap_3_lines() {
  css.compose(
    css.class([
      css.overflow("hidden"),
      css.text_overflow("ellipsis"),
      css.display("-webkit-box"),
      css.property("-webkit-line-clamp", "2"),
      css.property("-webkit-box-orient", "vertical"),
      css.property("line-clamp", "3"),
    ]),
  )
}

pub fn text_center() {
  css.class([css.text_align("center")])
}

pub fn text_bold() {
  css.class([css.font_weight("600")])
}
