import lustre/attribute as a
import lustre/element.{type Element}
import lustre/event as e
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h

/// A hamburger menu icon
fn hamburger() -> Element(msg) {
  // The SVG code in the string in this function is modified from https://codepen.io/ainalem/pen/wvKOEMV
  // Here is the original MIT license:

  // Copyright (c) 2026 - Mikael Ainalem - https://codepen.io/ainalem/pen/wvKOEMV

  // Permission is hereby granted, free of charge, to any person 
  // obtaining a copy of this software and associated documentation 
  // files (the "Software"), to deal in the Software without restriction,
  // including without limitation the rights to use, copy, modify, 
  // merge, publish, distribute, sublicense, and/or sell copies of 
  // the Software, and to permit persons to whom the Software is 
  // furnished to do so, subject to the following conditions:

  // The above copyright notice and this permission notice shall 
  // be included in all copies or substantial portions of the Software.

  // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
  // EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
  // OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
  // NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
  // HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
  // WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
  // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
  // DEALINGS IN THE SOFTWARE.

  element.unsafe_raw_html(
    "",
    "div",
    [a.style("width", "100px"), a.style("height", "100px")],
    "
      <svg width=\"100\" height=\"100\" viewBox=\"0 0 100 100\" class=\"hamburger\">
        <path class=\"line line1\" d=\"M 20,29.000046 H 80.000231 C 80.000231,29.000046 94.498839,28.817352 94.532987,66.711331 94.543142,77.980673 90.966081,81.670246 85.259173,81.668997 79.552261,81.667751 75.000211,74.999942 75.000211,74.999942 L 25.000021,25.000058\" />
        <path class=\"line line2\" d=\"M 20,50 H 80\" />
        <path class=\"line line3\" d=\"M 20,70.999954 H 80.000231 C 80.000231,70.999954 94.498839,71.182648 94.532987,33.288669 94.543142,22.019327 90.966081,18.329754 85.259173,18.331003 79.552261,18.332249 75.000211,25.000058 75.000211,25.000058 L 25.000021,74.999942\" />
      </svg>
    ",
  )
}

/// An animated hamburger menu button.
pub fn menu_button(state: State, on_click: msg) -> Element(msg) {
  h.button(
    css.class([
      css.background_color("transparent"),
      css.border("none"),
      css.cursor("pointer"),
      css.display("flex"),
      css.padding_("0"),
      css.width(length.px(100)),
      css.height(length.px(100)),
    ]),
    [
      e.on_click(on_click),
      a.aria_label(case state {
        Open -> "Close menu"
        Closed -> "Open menu"
      }),
      a.classes([
        #("opened", case state {
          Open -> True
          Closed -> False
        }),
      ]),
    ],
    [hamburger()],
  )
}

/// Represents whether a navigation menu is open or closed.
pub type State {
  Open
  Closed
}

pub fn toggle(state: State) -> State {
  case state {
    Open -> Closed
    Closed -> Open
  }
}

pub fn is_open(state: State) -> Bool {
  case state {
    Open -> True
    Closed -> False
  }
}
