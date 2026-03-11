import gleam/dynamic/decode

/// Represents a listing's seller
pub type Seller {
  Seller(id: String, name: String, email: String)
}

pub fn decoder() -> decode.Decoder(Seller) {
  use id <- decode.field("id", decode.string)
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(Seller(id:, name:, email:))
}
