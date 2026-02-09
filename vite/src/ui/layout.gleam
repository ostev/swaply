import gleam/json
import lustre/attribute.{type Attribute}
import sketch/css
import sketch/lustre/element.{type Element}
import sketch/lustre/element/html as h

pub type Spacing {
  Center
  SpaceBetween
  SpaceAround
  SpaceEvenly
  Start
  End
}

fn spacing_to_string(spacing: Spacing) -> String {
  case spacing {
    Center -> "center"
    SpaceBetween -> "space-between"
    SpaceAround -> "space-around"
    SpaceEvenly -> "space-evenly"
    Start -> "start"
    End -> "end"
  }
}

pub fn row(spacing: Spacing) -> css.Class {
  css.class([
    css.display("flex"),
    css.align_items("center"),
    css.justify_content(spacing_to_string(spacing)),
    css.flex_direction("row"),
  ])
}

pub fn column(spacing: Spacing) -> css.Class {
  css.class([
    css.display("flex"),
    css.justify_items("center"),
    css.align_items(spacing_to_string(spacing)),
    css.flex_direction("column"),
  ])
}
