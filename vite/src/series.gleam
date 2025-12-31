import gleam/int
import gleam/list
import gleam/result

pub opaque type Series(a) {
  Series(generator: fn(Int) -> Result(a, Nil))
}

pub fn from_generator(generator: fn(Int) -> Result(a, Nil)) -> Series(a) {
  Series(generator:)
}

pub fn at(series: Series(a), index: Int) -> Result(a, Nil) {
  series.generator(index)
}

pub fn before(series: Series(a), index: Int) -> Result(a, Nil) {
  series |> at(index - 1)
}

pub fn after(series: Series(a), index: Int) -> Result(a, Nil) {
  series |> at(index + 1)
}

pub fn map(series: Series(a), generator: fn(a) -> b) -> Series(b) {
  Series(generator: fn(index) {
    series
    |> at(index)
    |> result.map(generator)
  })
}

pub fn window(series: Series(a), center: Int, size: Int) -> List(a) {
  let right_index =
    center
    + case int.is_even(size) {
      True -> size / 2
      False -> size / 2 + 1
    }

  let left_index = center - size / 2

  series |> generate_until(left_index, right_index)
}

pub fn generate_until(series: Series(a), index: Int, end_index: Int) -> List(a) {
  series
  |> fold_until(end_index, index, list.prepend, [])
  |> list.reverse
}

pub fn fold_for(
  series: Series(a),
  index: Int,
  length: Int,
  fun: fn(b, a) -> b,
  accumulator: b,
) -> b {
  fold_until(series, index, index + length, fun, accumulator)
}

fn fold_until(
  series: Series(a),
  index: Int,
  end_index: Int,
  f: fn(b, a) -> b,
  accumulator: b,
) -> b {
  case index <= end_index {
    True ->
      case series |> at(index) {
        Ok(value) ->
          fold_until(series, index + 1, end_index, f, f(accumulator, value))
        Error(_) -> accumulator
      }
    False -> accumulator
  }
}
