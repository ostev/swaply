import gleam/dynamic/decode
import tempo/datetime

pub fn datetime() {
  use raw_string <- decode.then(decode.string)

  case datetime.parse_any(raw_string) {
    Ok(datetime) -> decode.success(datetime)
    Error(error) ->
      decode.failure(
        datetime.literal("2000-01-01T00:00:00Z"),
        expected: datetime.describe_parse_error(error),
      )
  }
}
