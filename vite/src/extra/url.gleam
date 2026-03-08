pub fn replace_empty_with_root(url: String) {
  case url {
    "" -> "/"
    _ -> url
  }
}
