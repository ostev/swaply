/// If the given URL is empty, replaces it with the root page so
/// it's still a valid URL string.
pub fn replace_empty_with_root(url: String) {
  case url {
    "" -> "/"
    _ -> url
  }
}
