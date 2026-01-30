import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri
import lenient_parse
import listing.{type Listing}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/event as e
import phosphor
import sequence
import tempo
import tempo/date
import tempo/datetime
import tempo/offset

pub type Cell(msg) =
  List(Element(msg))

pub type Row(msg) =
  List(Cell(msg))

pub fn heading(text: String) -> Element(msg) {
  h.th([], [h.text(text)])
}

pub fn view(headings headings: List(String), rows rows: List(Row(msg))) {
  h.table([], [
    h.thead([], [
      h.tr(
        [],
        headings
          |> list.map(fn(text) { h.th([], [h.text(text)]) }),
      ),
    ]),
    keyed.tbody(
      [],
      rows
        |> list.index_map(fn(cells, index) {
          #(
            int.to_string(index),
            h.tr(
              [],
              cells
                |> list.map(h.td([], _)),
            ),
          )
        }),
    ),
  ])
}
