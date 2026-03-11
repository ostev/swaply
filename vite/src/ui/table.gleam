/// Contains a set of functions to make dealing with HTML
/// tables nicer.
import gleam/int
import gleam/list
import lustre/element.{type Element}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import sketch/lustre/element/keyed
import ui/fonts
import ui/styles

pub type Cell(msg) =
  List(Element(msg))

/// Each row contains a list of columns.
pub type Row(msg) =
  List(Cell(msg))

pub fn heading(text: String) -> Element(msg) {
  h.th(
    css.class([
      fonts.inter(),
      css.font_size(length.px(20)),
      css.font_weight("500"),
      css.text_align("start"),
    ]),
    [],
    [
      h.text(text),
    ],
  )
}

/// Creates a table from a list of headings and a list of cells in row-major
/// order.
pub fn view(headings headings: List(String), rows rows: List(Row(msg))) {
  h.table(
    css.class([
      css.compose(styles.card()),
      css.width(length.percent(100)),
      fonts.inter(),

      css.border_spacing_("0.5rem 1rem"),
    ]),
    [],
    [
      h.thead(css.class([]), [], [
        h.tr(
          css.class([]),
          [],
          headings
            |> list.map(heading),
        ),
      ]),
      keyed.tbody(
        css.class([]),
        [],
        rows
          |> list.index_map(fn(cells, index) {
            #(
              int.to_string(index),
              h.tr(
                css.class([]),
                [],
                cells
                  |> list.map(h.td(css.class([]), [], _)),
              ),
            )
          }),
      ),
    ],
  )
}
