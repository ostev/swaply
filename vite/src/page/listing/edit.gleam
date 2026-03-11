import api
import extra/time as extra_time
import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri
import iv
import listing.{type Listing}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/event as e
import modem
import rsvp
import shared.{type Shared}
import sketch/css
import sketch/css/length
import sketch/lustre/element/html as h
import tempo
import tempo/date
import tempo/datetime
import tempo/error as tempo_error
import tempo/offset
import ui
import ui/button.{button}
import ui/fonts
import ui/input
import ui/layout
import ui/listing as listing_ui
import ui/styles
import ui/tags

pub type Model {
  Model(mode: Mode, form: Form, error: Option(EditError))
}

pub type Mode {
  Create
  Update(id: String)
}

/// Represents a partially-complete listing
pub type Form {
  Form(
    name: String,
    date: Option(String),
    time: Option(String),
    tags: Set(String),
    sorted_tags: List(String),
    current_tag: String,
    items: iv.Array(listing.ItemInput),
    is_published: Bool,
    description: String,
    short_description: String,
    location: String,
    is_editable: Bool,
  )
}

pub type EditError {
  NoDateProvided
  NoTimeProvided
  DateParseError(tempo_error.DateParseError)
  TimeParseError(extra_time.ParseError)
  IncompleteItem
  ServerCreationError(ServerResponse)
  AttemptedToEditNonexistentListing
  RsvpError(rsvp.Error)
  InvalidId
}

pub type ServerResponse {
  Unauthorised
  InvalidName
  InvalidPricing
  InvalidDescription
  InvalidShortDescription
  InvalidQuantity
  InvalidLocation
  TooManyTags
  TooManyItems
  NameAlreadyUsed
  DateInPast
}

fn server_response_decoder() -> decode.Decoder(ServerResponse) {
  use variant <- decode.field("result", decode.string)
  case variant {
    "unauthorised" -> decode.success(Unauthorised)
    "invalid_name" -> decode.success(InvalidName)
    "invalid_pricing" -> decode.success(InvalidPricing)
    "invalid_quantity" -> decode.success(InvalidQuantity)
    "invalid_description" -> decode.success(InvalidDescription)
    "invalid_short_description" -> decode.success(InvalidShortDescription)
    "invalid_location" -> decode.success(InvalidLocation)
    "name_already_used" -> decode.success(NameAlreadyUsed)
    "too_many_tags" -> decode.success(TooManyTags)
    "too_many_items" -> decode.success(TooManyItems)
    "date_in_past" -> decode.success(DateInPast)
    _ -> decode.failure(Unauthorised, "ServerResponse")
  }
}

pub fn init(shared_model: Shared, mode: Mode) -> #(Model, Effect(Msg)) {
  let check_auth = shared.check_authenticated(shared_model)

  #(
    Model(
      mode:,
      form: Form(
        name: "",
        date: option.None,
        time: option.None,
        tags: set.new(),
        sorted_tags: [],
        items: iv.from_list([
          listing.ItemInput(name: "", price: "", quantity: ""),
        ]),
        current_tag: "",
        is_published: False,
        short_description: "",
        description: "",
        location: "",
        is_editable: case mode {
          Create -> True
          Update(_) -> False
        },
      ),
      error: option.None,
    ),
    case mode {
      Create -> check_auth
      Update(id) ->
        effect.batch([check_auth, listing.get(id, PrefillFormResponseReceived)])
    },
  )
}

pub type Msg {
  ResponseReceived(Result(String, rsvp.Error))
  PrefillFormResponseReceived(Result(Listing, rsvp.Error))

  UpdateName(String)
  UpdateDate(String)
  UpdateTime(String)
  UpdateShortDescription(String)
  UpdateDescription(String)
  UpdateLocation(String)
  UpdateIsPublished(Bool)

  CreateTags(List(String))
  DeleteTag(String)
  UpdateTicketType(listing.ItemInput, index: Int)
  DeleteTicketType(index: Int)
  AddTicketType(listing.ItemInput)
  UpdateCurrentTag(String)
  SubmitForm
  NoOp
}

pub fn update(shared: Shared, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    NoOp -> #(model, effect.none())

    UpdateName(name) -> #(
      Model(..model, form: Form(..model.form, name:)),
      effect.none(),
    )
    UpdateDate(date) -> {
      #(
        Model(..model, form: Form(..model.form, date: option.Some(date))),
        effect.none(),
      )
    }
    UpdateTime(time) -> {
      #(
        Model(..model, form: Form(..model.form, time: option.Some(time))),
        effect.none(),
      )
    }
    UpdateCurrentTag(current_tag) -> {
      #(Model(..model, form: Form(..model.form, current_tag:)), effect.none())
    }
    CreateTags(new_tags) -> {
      case new_tags {
        [] -> {
          #(model, effect.none())
        }
        new_tags -> {
          let tags =
            model.form.tags
            |> set.union(set.from_list(new_tags))

          #(
            Model(
              ..model,
              form: Form(
                ..model.form,
                tags:,
                current_tag: "",
                sorted_tags: tags.sort(tags),
              ),
            ),
            effect.none(),
          )
        }
      }
    }
    DeleteTag(tag) -> {
      let tags = model.form.tags |> set.delete(tag)

      #(
        Model(
          ..model,
          form: Form(..model.form, tags:, sorted_tags: tags.sort(tags)),
        ),
        effect.none(),
      )
    }

    UpdateTicketType(item_type, index) -> {
      let items =
        model.form.items
        |> iv.set(index, item_type)
        |> result.unwrap(model.form.items)

      #(Model(..model, form: Form(..model.form, items:)), effect.none())
    }

    DeleteTicketType(index) -> {
      let items =
        model.form.items
        |> iv.delete(index)
        |> result.unwrap(model.form.items)

      #(Model(..model, form: Form(..model.form, items:)), effect.none())
    }

    AddTicketType(item_type) -> {
      let items =
        model.form.items
        |> iv.append(item_type)

      #(Model(..model, form: Form(..model.form, items:)), effect.none())
    }

    UpdateShortDescription(short_description) -> {
      #(
        Model(..model, form: Form(..model.form, short_description:)),
        effect.none(),
      )
    }

    UpdateDescription(description) -> {
      #(Model(..model, form: Form(..model.form, description:)), effect.none())
    }

    UpdateLocation(location) -> {
      #(Model(..model, form: Form(..model.form, location:)), effect.none())
    }

    UpdateIsPublished(is_published) -> {
      #(Model(..model, form: Form(..model.form, is_published:)), effect.none())
    }

    SubmitForm -> {
      case submit(model.form, model.mode, shared.csrf_token) {
        Ok(create_effect) -> #(model, create_effect)
        Error(error) -> #(
          Model(..model, error: option.Some(error)),
          effect.none(),
        )
      }
    }
    ResponseReceived(Ok(listing_id)) -> {
      #(
        model,
        modem.push(
          "/listing/" <> uri.percent_encode(listing_id),
          option.None,
          option.None,
        ),
      )
    }

    ResponseReceived(Error(error)) -> {
      #(
        Model(
          ..model,
          error: option.Some(case error {
            rsvp.HttpError(response) -> {
              json.parse(response.body, server_response_decoder())
              |> result.map(ServerCreationError)
              |> result.unwrap(RsvpError(error))
            }
            _ -> {
              io.println_error(string.inspect(error))
              RsvpError(error)
            }
          }),
        ),
        effect.none(),
      )
    }

    PrefillFormResponseReceived(Ok(listing)) -> {
      #(
        Model(..model, form: {
          let local_datetime =
            listing.date |> datetime.to_offset(offset.local())

          Form(
            name: listing.name,
            date: option.Some(
              local_datetime
              |> datetime.get_date()
              |> date.format(tempo.ISO8601Date),
            ),
            time: option.Some(
              local_datetime
              |> datetime.get_time()
              |> extra_time.format_as_24hr,
            ),
            tags: set.from_list(listing.tags),
            sorted_tags: listing.tags |> list.sort(string.compare),
            items: iv.from_list(listing.items)
              |> iv.map(fn(item_type) {
                listing.ItemInput(
                  name: item_type.name,
                  price: float.to_string(item_type.price),
                  quantity: int.to_string(item_type.quantity),
                )
              }),
            current_tag: "",
            is_published: listing.is_published,
            short_description: listing.short_description,
            description: listing.description,
            location: listing.location,
            is_editable: True,
          )
        }),
        effect.none(),
      )
    }

    PrefillFormResponseReceived(Error(error)) -> {
      #(
        Model(
          ..model,
          error: option.Some(case error {
            rsvp.HttpError(response) -> {
              case response.status {
                404 -> AttemptedToEditNonexistentListing
                _ -> RsvpError(error)
              }
            }
            _ -> RsvpError(error)
          }),
        ),
        effect.none(),
      )
    }
  }
}

/// Parses a date string from an input element.
fn parse_date(
  date_string: String,
) -> Result(tempo.Date, tempo_error.DateParseError) {
  date_string
  |> date.parse(tempo.ISO8601Date)
}

/// Determines if a given date string is in the future.
fn is_date_valid(date_string: Option(String)) -> Bool {
  date_string
  |> option.map(parse_date)
  |> option.map(fn(date_result) {
    date_result
    |> result.map(fn(date) {
      date
      |> date.is_later_or_equal(date.current_local())
    })
    |> result.unwrap(False)
  })
  |> option.unwrap(False)
}

/// Determines if a given time string is parseable.
fn is_time_valid(time_string: String) -> Bool {
  case extra_time.parse(time_string) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Creates a datetime from the provided date and time strings
fn get_datetime(
  date: Option(String),
  time: Option(String),
) -> Result(tempo.DateTime, EditError) {
  use date_string <- result.try(
    date
    |> option.to_result(NoDateProvided),
  )

  use date <- result.try(
    parse_date(date_string)
    |> result.map_error(DateParseError),
  )

  use time_string <- result.try(
    time
    |> option.to_result(NoTimeProvided),
  )
  use time <- result.try(
    extra_time.parse(time_string)
    |> result.map_error(TimeParseError),
  )
  Ok(datetime.new(date, time, offset.local()))
}

/// Submits the updated edits to the server
fn submit(
  form: Form,
  mode: Mode,
  with_token csrf_token: String,
) -> Result(Effect(Msg), EditError) {
  use datetime <- result.try(get_datetime(form.date, form.time))

  use json_items <- result.try(
    form.items
    |> iv.to_list
    |> list.try_map(fn(item_type) {
      listing.parse_item_type(item_type)
      |> result.map(listing.item_type_to_json)
    })
    |> result.replace_error(IncompleteItem),
  )

  let tags = form.tags |> set.insert(form.current_tag)

  let body =
    json.object([
      #("name", json.string(form.name)),
      #("date", json.string(datetime |> datetime.format(tempo.ISO8601Seconds))),
      #("is_published", json.bool(form.is_published)),
      #("items", json.preprocessed_array(json_items)),
      #(
        "tags",
        json.array(set.to_list(tags) |> list.sort(string.compare), json.string),
      ),
      #("short_description", json.string(form.short_description)),
      #("description", json.string(form.description)),
      #("location", json.string(form.location)),
    ])
  let handler =
    rsvp.expect_json(
      {
        use id <- decode.field("id", decode.string)

        decode.success(id)
      },
      ResponseReceived,
    )

  case mode {
    Create ->
      api.send(
        body:,
        to: listing.api_root,
        with: http.Post,
        handler:,
        with_token: csrf_token,
      )
      |> result.replace_error(InvalidId)
    Update(id) -> {
      api.send(
        body:,
        to: listing.api_url(id),
        with: http.Patch,
        handler:,
        with_token: csrf_token,
      )
      |> result.replace_error(InvalidId)
    }
  }
}

/// Displays the end data information for the current listing
fn listing_date(model: Model) -> Element(Msg) {
  h.div_([], [
    h.div(
      css.class([
        css.compose(layout.row(layout.SpaceBetween)),
        css.align_items("start"),
        css.gap(length.px(12)),
      ]),
      [],
      [
        h.div(css.class([css.flex("1")]), [], [
          input.generic_(
            type_: "date",
            label: "Date",
            name: "date",
            value: model.form.date,
            on_input: UpdateDate,
            is_valid: is_date_valid(model.form.date),
          ),
        ]),

        h.div(css.class([css.flex("1")]), [], [
          input.generic_(
            type_: "time",
            label: "Time",
            name: "time",
            value: model.form.time,
            on_input: UpdateTime,
            is_valid: model.form.time
              |> option.map(is_time_valid)
              |> option.unwrap(False),
          ),
        ]),
      ],
    ),
  ])
}

/// Displays the panel for validation errors
fn error_panel(model: Model) -> Element(Msg) {
  let date_is_valid =
    { model.form.date |> option.map(string.is_empty) |> option.unwrap(True) }
    || is_date_valid(model.form.date)

  h.div_([], [
    ui.panel(
      ui.ErrorPanel,
      !date_is_valid || option.is_some(model.error),
      case model.error {
        option.Some(error) ->
          case error {
            ServerCreationError(server_response) -> {
              case server_response {
                InvalidName ->
                  "Please provide a name for the listing that is between 3 and 30 characters long."
                InvalidPricing ->
                  "One of the items on offer has a price that is lower than $0 or higher than $1 000 000."
                InvalidQuantity ->
                  "One of the items on offer has a quantity that is lower than 0 or higher than 1 000 000."
                InvalidDescription ->
                  "Please provide a description that is between 3 and 10 000 characters long."
                InvalidShortDescription ->
                  "Please provide a short description that is between 3 and 300 characters long."
                InvalidLocation ->
                  "Please provide a location that is no more than 200 characters long."
                TooManyTags -> "Please provide no more than 6 tags."
                TooManyItems -> "Please provide no more than 20 items."
                NameAlreadyUsed -> "A listing with this name already exists."
                DateInPast -> "The date you provided is in the past."
                Unauthorised ->
                  "You don't have access to edit this listing. Make sure you're logged in."
              }
            }

            NoDateProvided -> {
              "Please provide a date for the listing."
            }
            DateParseError(_) ->
              "Please provide a valid date in the future for the listing."
            IncompleteItem -> "One of the items is incomplete."
            NoTimeProvided -> "Please provide a time for the listing."
            RsvpError(_) ->
              "A network error occurred while creating your listing. Please try again"
            TimeParseError(_) ->
              "Please provide a valid time in the future for the listing."
            AttemptedToEditNonexistentListing ->
              "The listing you are trying to edit does not exist."
            InvalidId -> "The listing ID contained within the URL is invalid."
          }
        option.None ->
          case date_is_valid {
            False -> "Please enter a date in the future."
            True -> ""
          }
      },
    ),
  ])
}

pub fn view(model: Model) -> Element(Msg) {
  h.div(layout.row(layout.Center), [], [
    case model.form.is_editable {
      False -> element.none()
      True ->
        h.form(
          css.class([
            css.max_width(length.rem(26.0)),
            css.width(length.percent(100)),
            css.compose(styles.card()),

            css.margin_top(length.px(8)),
            css.margin_bottom(length.px(20)),

            css.compose(layout.column(layout.Center)),
            css.gap(length.px(8)),
          ]),
          [
            e.on_submit(fn(_) { SubmitForm }),
            e.advanced("keydown", {
              use key <- decode.field("key", decode.string)
              use tag_name <- decode.field("target", {
                use tag_name <- decode.field("tagName", decode.string)

                decode.success(tag_name)
              })

              decode.success(case key {
                "Enter" if tag_name != "TEXTAREA" ->
                  e.handler(
                    NoOp,
                    prevent_default: True,
                    stop_propagation: False,
                  )
                _ ->
                  e.handler(
                    NoOp,
                    prevent_default: False,
                    stop_propagation: False,
                  )
              })
            }),
          ],
          [
            input.title(
              css.class([]),
              name: "title",
              label: "Title",
              value: model.form.name,
              on_input: UpdateName,
            ),

            h.div(
              css.class([
                css.width(length.percent(95)),
              ]),
              [],
              [
                ui.fieldset([
                  ui.h3(styles.text_center(), "Details"),
                  input.textarea(
                    label: "Short description",
                    name: "short_description",
                    value: model.form.short_description,
                    on_input: UpdateShortDescription,
                    is_valid: True,
                    height: length.em(4.0),
                  ),

                  input.textarea(
                    label: "Description",
                    name: "description",
                    value: model.form.description,
                    on_input: UpdateDescription,
                    is_valid: True,
                    height: length.em(10.0),
                  ),

                  tags.tags_input(
                    label: "Tags",
                    name: "tags",
                    sorted_tags: model.form.sorted_tags,
                    value: model.form.current_tag,
                    on_update_value: UpdateCurrentTag,
                    on_create_tags: CreateTags,
                    on_remove_tag: DeleteTag,
                  ),

                  input.generic_(
                    type_: "text",
                    label: "Pickup location",
                    name: "location",
                    value: option.Some(model.form.location),
                    on_input: UpdateLocation,
                    is_valid: string.length(model.form.location |> string.trim)
                      > 2,
                  ),
                ]),

                ui.fieldset([
                  ui.h3(styles.text_center(), "Items for offer"),

                  h.div(
                    css.class([
                      css.width(length.percent(100)),
                    ]),
                    [],
                    [
                      h.div(
                        css.class([
                          css.compose(layout.column(layout.Start)),
                          css.gap(length.em(2.0)),
                          css.width(length.percent(100)),
                        ]),
                        [],
                        model.form.items
                          |> iv.to_list
                          |> list.index_map(fn(item_type, index) {
                            h.div(
                              css.class([
                                css.compose(layout.column(layout.Start)),
                                css.gap(length.px(4)),
                                css.width(length.percent(100)),
                              ]),
                              [],
                              [
                                listing_ui.item_input(
                                  item_type,
                                  "item_type_" <> int.to_string(index),
                                  UpdateTicketType(_, index:),
                                ),
                                button(
                                  button.Danger,
                                  "Delete",
                                  DeleteTicketType(index),
                                ),
                              ],
                            )
                          }),
                      ),

                      h.div(
                        css.class([
                          css.compose(layout.row(layout.End)),
                        ]),
                        [],
                        [
                          button(
                            button.Primary,
                            "Add",
                            AddTicketType(listing.ItemInput(
                              name: "",
                              price: "",
                              quantity: "",
                            )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ]),

                ui.fieldset([
                  ui.h3(
                    css.class([
                      css.compose(styles.text_center()),
                      css.margin_block_end(length.px(0)),
                    ]),
                    "End date",
                  ),
                  h.p(
                    css.class([
                      fonts.inter(),
                      fonts.size_md(),
                      styles.text_italic(),
                    ]),
                    [],
                    [
                      h.text("When your listing will be hidden"),
                    ],
                  ),
                  listing_date(model),

                  error_panel(model),

                  h.div(
                    css.class([
                      css.compose(layout.row(layout.SpaceBetween)),
                      css.width(length.percent(100)),
                    ]),
                    [],
                    [
                      input.toggle(
                        label: "Published?",
                        name: "is_published",
                        is_checked: model.form.is_published,
                        on_input: UpdateIsPublished,
                      ),

                      button.submit(button.Primary, case model.mode {
                        Create -> "Create"
                        Update(_) -> "Update"
                      }),
                    ],
                  ),
                ]),
              ],
            ),
          ],
        )
    },
  ])
}
