import gleam/list
import gleam/set

pub fn is_unique(list: List(a)) -> Bool {
  set.size(set.from_list(list)) == list.length(list)
}
