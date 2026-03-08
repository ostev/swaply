import lustre/attribute.{type Attribute} as a
import lustre/element.{type Element}
import lustre/event as e
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import ui/colors
import ui/fonts
import ui/styles

pub type Role {
  Primary
  Secondary
  Borderless
  Danger
  Disabled
}

pub fn link(role role: Role, text text: String, to href: String) -> Element(msg) {
  button_internal(h.a, [a.type_("submit"), a.href(href)], role, text)
}

pub fn button(role: Role, text: String, on_click: msg) -> Element(msg) {
  with_attrs(role, [], text, on_click)
}

pub fn with_attrs(
  role: Role,
  attrs: List(Attribute(msg)),
  text: String,
  on_click: msg,
) -> Element(msg) {
  button_internal(
    h.button,
    [a.type_("button"), e.on_click(on_click), ..attrs],
    role,
    text,
  )
}

pub fn submit(role: Role, text: String) -> Element(msg) {
  button_internal(h.button, [a.type_("submit")], role, text)
}

fn button_internal(
  container: fn(css.Class, List(a.Attribute(msg)), List(Element(a))) ->
    Element(msg),
  attrs: List(Attribute(msg)),
  role: Role,
  text: String,
) -> Element(msg) {
  let #(bg_color, hover_color, text_color) = case role {
    Primary | Borderless -> #(
      colors.primary_background,
      colors.primary_foreground,
      colors.black,
    )
    Secondary -> #(colors.secondary_button, colors.four, colors.black)
    Danger -> #(colors.red, colors.red_light, "black")
    Disabled -> #(colors.disabled, colors.disabled, "black")
  }

  container(
    css.class([
      css.color(text_color),
      css.background_color(bg_color),

      fonts.inter(),
      fonts.size_md(),

      css.compose(case role {
        Borderless -> css.class([css.border("none")])
        _ ->
          css.class([css.border_style("solid"), css.border_width(length.px(1))])
      }),
      css.border_radius(length.px(6)),

      css.padding_inline(length.px(10)),
      css.padding_block(length.px(6)),

      css.text_align("center"),

      case role {
        Disabled -> css.border_color("white")
        _ ->
          css.compose(
            css.class([
              css.border_color("black"),

              css.transition("box-shadow 0.3s, border-color 0.3s"),
              css.box_shadow("3px 3px 5px " <> colors.button_box_shadow),
              css.hover([
                css.box_shadow("2px 2px 3px " <> colors.button_box_shadow),
              ]),
              css.active([
                css.box_shadow("0px 0px 2px " <> colors.button_box_shadow),
              ]),
            ]),
          )
      },

      css.transition("background-color 0.3s, box-shadow 0.3s"),
      css.cursor(case role {
        Disabled -> "not-allowed"
        _ -> "pointer"
      }),

      css.text_decoration("none"),

      css.hover([css.background_color(hover_color)]),
    ]),
    [
      a.aria_disabled(case role {
        Disabled -> True
        _ -> False
      }),
      ..attrs
    ],
    [h.text(text)],
  )
}

pub fn icon(
  class: css.Class,
  attributes: List(a.Attribute(msg)),
  label: String,
  icon: Element(msg),
) {
  h.button(
    css.class([
      css.border_color("black"),
      css.border_style("solid"),
      css.border_radius(length.percent(50)),
      css.border_width(length.px(1)),
      css.width(length.px(40)),
      css.height(length.px(40)),
      css.padding_("0"),
      css.display("flex"),
      css.justify_content("center"),
      css.align_items("center"),
      css.cursor("pointer"),

      css.compose(styles.interactive_box_shadow()),
      css.background_color(colors.primary_background),

      css.compose(class),
    ]),
    [a.aria_label(label), ..attributes],
    [
      icon,
    ],
  )
}
