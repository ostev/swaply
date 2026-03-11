import gleam/int
import gleam/list
import gleam/result

/// Represents a potentially-infinite sequence of terms, each
/// created by a generator function.
pub opaque type Sequence(a) {
  Sequence(start: Int, generator: fn(Int) -> Result(a, Nil))
}

/// Creates a new sequence from a generator function.
pub fn new(generator: fn(Int) -> Result(a, Nil)) -> Sequence(a) {
  Sequence(start: 0, generator:)
}

/// Changes the start index of a sequence.
pub fn with_start(sequence: Sequence(a), start: Int) -> Sequence(a) {
  Sequence(..sequence, start:)
}

/// Makes an infinite sequence finite by adding an end index.
/// The smallest end index will override any others.
pub fn limit(sequence: Sequence(a), limit: Int) -> Sequence(a) {
  Sequence(..sequence, generator: fn(index) {
    case index >= sequence.start, index <= sequence.start + limit - 1 {
      True, True -> sequence.generator(index)
      _, _ -> Error(Nil)
    }
  })
}

/// Calculates the term at a given index
pub fn at(sequence: Sequence(a), index: Int) -> Result(a, Nil) {
  case index >= sequence.start {
    True -> sequence.generator(index)
    False -> Error(Nil)
  }
}

/// Finds the term before a given index
pub fn before(sequence: Sequence(a), index: Int) -> Result(a, Nil) {
  sequence |> at(index - 1)
}

/// Finds the term after a given index
pub fn after(sequence: Sequence(a), index: Int) -> Result(a, Nil) {
  sequence |> at(index + 1)
}

/// Transforms a sequence into another sequence
pub fn map(sequence: Sequence(a), generator: fn(a) -> b) -> Sequence(b) {
  Sequence(..sequence, generator: fn(index) {
    sequence
    |> at(index)
    |> result.map(generator)
  })
}

/// Retrieves a window of a sequence with a set size and center>
pub fn window(
  sequence: Sequence(a),
  center center: Int,
  size size: Int,
) -> Sequence(a) {
  let left_index = int.max(center - size / 2, sequence.start)
  let right_index = left_index + size - 1

  let generator = fn(index: Int) {
    case index >= left_index, index <= right_index {
      True, True -> sequence.generator(index)
      _, _ -> Error(Nil)
    }
  }

  Sequence(start: left_index, generator:)
}

/// Transforms a sequence into a list. This will run forever if
/// the sequence is infinite.
pub fn generate(sequence: Sequence(a)) -> List(a) {
  sequence
  |> fold(list.prepend, [])
  |> list.reverse
}

/// Folds over a sequence with the gi
pub fn fold(sequence: Sequence(a), fun: fn(b, a) -> b, accumulator: b) -> b {
  fold_loop(sequence, fun, accumulator, sequence.start)
}

fn fold_loop(
  sequence: Sequence(a),
  fun: fn(b, a) -> b,
  accumulator: b,
  index: Int,
) -> b {
  case sequence.generator(index) {
    Ok(value) -> fold_loop(sequence, fun, fun(accumulator, value), index + 1)
    Error(_) -> accumulator
  }
}
