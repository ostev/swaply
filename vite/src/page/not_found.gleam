//// Contains the layout for the client-side-routed 404 page

import lustre/effect.{type Effect}
import lustre/element.{type Element}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import ui
import ui/layout

pub type Model {
  Model
}

pub type Msg

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model, effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}

pub fn view(_model: Model) -> Element(Msg) {
  h.div(
    css.class([
      css.compose(layout.column(layout.Center)),
      css.margin_top(length.px(24)),
    ]),
    [],
    [ui.h1("Page not found")],
  )
}
