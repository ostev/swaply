import lustre
import lustre/attribute as a
import lustre/element/html as h

pub fn main() {
  let app = lustre.element(h.p([a.class("text-xl")], [h.text("Hello, world!")]))
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
