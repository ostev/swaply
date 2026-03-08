import lustre/element.{type Element}
import sketch/lustre/element/html as h
import ui/layout

pub fn row(
  spacing: layout.Spacing,
  children: List(Element(msg)),
) -> Element(msg) {
  h.div(layout.row(spacing), [], children)
}

pub fn column(
  spacing: layout.Spacing,
  children: List(Element(msg)),
) -> Element(msg) {
  h.div(layout.column(spacing), [], children)
}
