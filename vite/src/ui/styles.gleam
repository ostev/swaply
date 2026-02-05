import sketch/css
import sketch/css/angle
import sketch/css/length
import sketch/css/transform

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
