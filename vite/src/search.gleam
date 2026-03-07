import gleam/order
import tempo
import tempo/instant

pub type Results(a) {
  Results(values: List(a), number_of_pages: Int, timestamp: tempo.Instant)
}

pub fn update(previous: Results(a), new: Results(a)) -> Results(a) {
  // If we've received the new search results after the previous ones,
  // update them. Otherwise, use the old results.
  case new.timestamp |> instant.compare(previous.timestamp) {
    order.Gt | order.Eq -> {
      new
    }
    _ -> {
      previous
    }
  }
}
