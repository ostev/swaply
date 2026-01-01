import gleam/int
import gleam/list
import gleam/result

pub opaque type Sequence(a) {
  Series(start: Int, generator: fn(Int) -> Result(a, Nil))
}

pub fn new(generator: fn(Int) -> Result(a, Nil)) -> Sequence(a) {
  Series(start: 0, generator:)
}

pub fn with_start(series: Sequence(a), start: Int) -> Sequence(a) {
  Series(..series, start:)
}

pub fn limit(series: Sequence(a), limit: Int) -> Sequence(a) {
  Series(..series, generator: fn(index) {
    case index >= series.start, index <= series.start + limit - 1 {
      True, True -> series.generator(index)
      _, _ -> Error(Nil)
    }
  })
}

pub fn at(series: Sequence(a), index: Int) -> Result(a, Nil) {
  case index >= series.start {
    True -> series.generator(index)
    False -> Error(Nil)
  }
}

pub fn before(series: Sequence(a), index: Int) -> Result(a, Nil) {
  series |> at(index - 1)
}

pub fn after(series: Sequence(a), index: Int) -> Result(a, Nil) {
  series |> at(index + 1)
}

pub fn map(series: Sequence(a), generator: fn(a) -> b) -> Sequence(b) {
  Series(..series, generator: fn(index) {
    series
    |> at(index)
    |> result.map(generator)
  })
}

pub fn window(
  series: Sequence(a),
  center center: Int,
  size size: Int,
) -> Sequence(a) {
  let left_index = int.max(center - size / 2, series.start)
  let right_index = left_index + size - 1

  let generator = fn(index: Int) {
    case index >= left_index, index <= right_index {
      True, True -> series.generator(index)
      _, _ -> Error(Nil)
    }
  }

  Series(start: left_index, generator:)
}

pub fn generate(series: Sequence(a)) -> List(a) {
  series
  |> fold(list.prepend, [])
  |> list.reverse
}

pub fn fold(series: Sequence(a), fun: fn(b, a) -> b, accumulator: b) -> b {
  fold_loop(series, fun, accumulator, series.start)
}

fn fold_loop(
  series: Sequence(a),
  fun: fn(b, a) -> b,
  accumulator: b,
  index: Int,
) -> b {
  case series.generator(index) {
    Ok(value) -> fold_loop(series, fun, fun(accumulator, value), index + 1)
    Error(_) -> accumulator
  }
}
