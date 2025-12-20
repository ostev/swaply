import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e

pub fn input(
  type_ type_: String,
  name name: String,
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> msg,
  is_valid is_valid: Bool,
) -> Element(msg) {
  element.fragment([
    h.label([a.for(name)], [h.text(label)]),
    h.input([
      a.type_(type_),
      a.name(name),
      a.value(value),
      a.classes([#("invalid", !is_valid)]),
      e.on_input(on_input),
    ]),
  ])
}
