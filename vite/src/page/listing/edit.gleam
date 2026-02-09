import extra/rsvp as extra_rsvp
import extra/time as extra_time
import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
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
import lustre/attribute as a
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
import ui/colors
import ui/fonts
import ui/layout
import ui/styles

pub type Model {
  Model(mode: Mode, form: Form, error: Option(EditError))
}

pub type Mode {
  Create
  Update(id: String)
}

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
  IncompleteTicketType
  ServerCreationError(ServerResponse)
  AttemptedToEditNonexistentListing
  RsvpError(rsvp.Error)
  InvalidId
}

pub type ServerResponse {
  Unauthorised
  InvalidName
  NameAlreadyUsed
}

fn server_response_decoder() -> decode.Decoder(ServerResponse) {
  use variant <- decode.field("result", decode.string)
  case variant {
    "unauthorised" -> decode.success(Unauthorised)
    "invalid_name" -> decode.success(InvalidName)
    "name_already_used" -> decode.success(NameAlreadyUsed)
    _ -> decode.failure(Unauthorised, "ServerResponse")
  }
}

pub fn init(shared_model: Shared, mode: Mode) -> #(Model, Effect(Msg)) {
  let check_auth = shared.check_authentication(shared_model)

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
          listing.ItemInput(name: "Standard", price: "", quantity: ""),
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
  ResponseReceived(Result(Listing, rsvp.Error))
  PrefillFormResponseReceived(Result(Listing, rsvp.Error))

  UpdatedName(String)
  UpdatedDate(String)
  UpdatedTime(String)
  UpdatedShortDescription(String)
  UpdatedDescription(String)
  UpdatedLocation(String)
  UpdatedIsPublished(Bool)

  CreatedTags(List(String))
  DeletedTag(String)
  UpdatedTicketType(listing.ItemInput, index: Int)
  DeletedTicketType(index: Int)
  AddedTicketType(listing.ItemInput)
  UpdateCurrentTag(String)
  SubmitForm
  NoOp
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    NoOp -> #(model, effect.none())

    UpdatedName(name) -> #(
      Model(..model, form: Form(..model.form, name:)),
      effect.none(),
    )
    UpdatedDate(date) -> {
      #(
        Model(..model, form: Form(..model.form, date: option.Some(date))),
        effect.none(),
      )
    }
    UpdatedTime(time) -> {
      #(
        Model(..model, form: Form(..model.form, time: option.Some(time))),
        effect.none(),
      )
    }
    UpdateCurrentTag(current_tag) -> {
      #(Model(..model, form: Form(..model.form, current_tag:)), effect.none())
    }
    CreatedTags(new_tags) -> {
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
                sorted_tags: ui.sort_tags(tags),
              ),
            ),
            effect.none(),
          )
        }
      }
    }
    DeletedTag(tag) -> {
      let tags = model.form.tags |> set.delete(tag)

      #(
        Model(
          ..model,
          form: Form(..model.form, tags:, sorted_tags: ui.sort_tags(tags)),
        ),
        effect.none(),
      )
    }

    UpdatedTicketType(item_type, index) -> {
      let items =
        model.form.items
        |> iv.set(index, item_type)
        |> result.unwrap(model.form.items)

      #(Model(..model, form: Form(..model.form, items:)), effect.none())
    }

    DeletedTicketType(index) -> {
      let items =
        model.form.items
        |> iv.delete(index)
        |> result.unwrap(model.form.items)

      #(Model(..model, form: Form(..model.form, items:)), effect.none())
    }

    AddedTicketType(item_type) -> {
      let items =
        model.form.items
        |> iv.append(item_type)

      #(Model(..model, form: Form(..model.form, items:)), effect.none())
    }

    UpdatedShortDescription(short_description) -> {
      #(
        Model(..model, form: Form(..model.form, short_description:)),
        effect.none(),
      )
    }

    UpdatedDescription(description) -> {
      #(Model(..model, form: Form(..model.form, description:)), effect.none())
    }

    UpdatedLocation(location) -> {
      #(Model(..model, form: Form(..model.form, location:)), effect.none())
    }

    UpdatedIsPublished(is_published) -> {
      #(Model(..model, form: Form(..model.form, is_published:)), effect.none())
    }

    SubmitForm -> {
      case submit(model.form, model.mode) {
        Ok(create_effect) -> #(model, create_effect)
        Error(error) -> #(
          Model(..model, error: option.Some(error)),
          effect.none(),
        )
      }
    }
    ResponseReceived(Ok(listing)) -> {
      #(
        model,
        modem.push(
          "/listing/" <> uri.percent_encode(listing.id),
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

fn parse_date(
  date_string: String,
) -> Result(tempo.Date, tempo_error.DateParseError) {
  date_string
  |> date.parse(tempo.ISO8601Date)
}

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

fn is_time_valid(time_string: String) -> Bool {
  case extra_time.parse(time_string) {
    Ok(_) -> True
    Error(_) -> False
  }
}

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

fn submit(form: Form, mode: Mode) -> Result(Effect(Msg), EditError) {
  use datetime <- result.try(get_datetime(form.date, form.time))

  use json_items <- result.try(
    form.items
    |> iv.to_list
    |> list.try_map(fn(item_type) {
      listing.parse_item_type(item_type)
      |> result.map(listing.item_type_to_json)
    })
    |> result.replace_error(IncompleteTicketType),
  )

  let body =
    json.object([
      #("name", json.string(form.name)),
      #("date", json.string(datetime |> datetime.format(tempo.ISO8601Seconds))),
      #("is_published", json.bool(form.is_published)),
      #("items", json.preprocessed_array(json_items)),
      #(
        "tags",
        json.array(
          set.to_list(form.tags) |> list.sort(string.compare),
          json.string,
        ),
      ),
      #("short_description", json.string(form.short_description)),
      #("description", json.string(form.description)),
      #("location", json.string(form.location)),
    ])
  let handler = rsvp.expect_json(listing.decoder(), ResponseReceived)

  case mode {
    Create -> Ok(rsvp.post(listing.api_prefix, body, handler))
    Update(id) -> {
      extra_rsvp.send(body:, to: listing.url(id), with: http.Patch, handler:)
      |> result.replace_error(InvalidId)
    }
  }
}

fn listing_date(model: Model) -> Element(Msg) {
  let date_is_valid = is_date_valid(model.form.date)

  h.div(
    css.class([
      css.compose(layout.row(layout.SpaceBetween)),
      css.align_items("start"),
      css.gap(length.px(12)),
    ]),
    [],
    [
      h.div(css.class([css.flex("1")]), [], [
        ui.input_(
          type_: "date",
          label: "Date",
          name: "date",
          value: model.form.date,
          on_input: UpdatedDate,
          is_valid: date_is_valid,
        ),

        case date_is_valid {
          True -> element.none()
          False ->
            h.p_([], [
              h.text("Please enter a date in the future."),
            ])
        },
      ]),

      h.div(css.class([css.flex("1")]), [], [
        ui.input_(
          type_: "time",
          label: "Time",
          name: "time",
          value: model.form.time,
          on_input: UpdatedTime,
          is_valid: model.form.time
            |> option.map(is_time_valid)
            |> option.unwrap(False),
        ),
      ]),
    ],
  )
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

            css.compose(layout.column(layout.Center)),
            css.gap(length.px(8)),
          ]),
          [
            e.on_submit(fn(_) { SubmitForm }),
            e.advanced("keydown", {
              use key <- decode.field("key", decode.string)

              decode.success(case key {
                "Enter" ->
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
            h.input(
              css.class([
                css.all("unset"),
                css.display("block"),

                css.padding(length.px(10)),
                css.background_color(colors.input_background),
                css.border_color(colors.black),
                css.border_style("solid"),
                css.border_width(length.px(1)),
                css.border_radius(length.px(6)),
                css.font_size(length.px(16)),

                css.transition("box-shadow 0.3s"),
                css.box_shadow("3px 3px 3px " <> colors.input_box_shadow),
                css.hover([
                  css.box_shadow("1px 1px 3px " <> colors.input_box_shadow),
                ]),
                css.active([
                  css.box_shadow("0px 0px 2px " <> colors.input_box_shadow),
                ]),

                css.placeholder([css.color(colors.placeholder_text)]),

                fonts.merriweather(),
                css.font_size(length.px(30)),

                css.width(length.percent(100)),
                css.max_width(length.em(10.0)),
                css.box_sizing("border-box"),

                css.margin_bottom(length.px(8)),
              ]),
              [
                a.value(model.form.name),
                a.placeholder("Title..."),
                e.on_input(UpdatedName),

                a.aria_label("Title"),
                a.name("title"),
              ],
            ),

            h.div(
              css.class([
                css.width(length.percent(95)),
              ]),
              [],
              [
                ui.fieldset([
                  ui.h3("Details"),
                  ui.textarea(
                    label: "Short description",
                    name: "short_description",
                    value: model.form.short_description,
                    on_input: UpdatedShortDescription,
                    is_valid: True,
                  ),

                  ui.textarea(
                    label: "Description",
                    name: "description",
                    value: model.form.description,
                    on_input: UpdatedDescription,
                    is_valid: True,
                  ),

                  ui.tags_input(
                    label: "Tags",
                    name: "tags",
                    sorted_tags: model.form.sorted_tags,
                    value: model.form.current_tag,
                    on_update_value: UpdateCurrentTag,
                    on_create_tags: CreatedTags,
                    on_remove_tag: DeletedTag,
                  ),

                  ui.input_(
                    type_: "text",
                    label: "Pickup location",
                    name: "location",
                    value: option.Some(model.form.location),
                    on_input: UpdatedLocation,
                    is_valid: True,
                  ),
                ]),

                ui.fieldset([
                  ui.h3("Items for offer"),

                  h.div_([], [
                    h.div_(
                      [],
                      model.form.items
                        |> iv.to_list
                        |> list.index_map(fn(item_type, index) {
                          h.div_([], [
                            ui.item_type_input(
                              item_type,
                              "item_type_" <> int.to_string(index),
                              UpdatedTicketType(_, index:),
                            ),
                            h.button_(
                              [
                                e.on_click(DeletedTicketType(index)),
                                a.type_("button"),
                              ],
                              [
                                h.text("Delete"),
                              ],
                            ),
                          ])
                        }),
                    ),

                    h.button_(
                      [
                        a.type_("button"),
                        e.on_click(
                          AddedTicketType(listing.ItemInput(
                            name: "",
                            price: "",
                            quantity: "",
                          )),
                        ),
                      ],
                      [h.text("Add")],
                    ),
                  ]),
                ]),

                ui.fieldset([
                  ui.h3("Management"),
                  listing_date(model),

                  ui.toggle_input(
                    label: "Published?",
                    name: "is_published",
                    is_checked: model.form.is_published,
                    on_input: UpdatedIsPublished,
                  ),
                ]),

                h.button_([a.type_("submit")], [
                  h.text(case model.mode {
                    Create -> "Create"
                    Update(_) -> "Update"
                  }),
                ]),

                h.div_([], case model.error {
                  option.Some(error) -> {
                    [
                      h.p_([], [
                        h.text(case error {
                          ServerCreationError(server_response) -> {
                            case server_response {
                              InvalidName ->
                                "Please provide a name for the listing that is longer than 3 characters."
                              NameAlreadyUsed ->
                                "An listing with this name already exists."
                              Unauthorised ->
                                "Please log in to create an listing."
                            }
                          }

                          NoDateProvided -> {
                            "Please provide a date for the listing."
                          }
                          DateParseError(_) ->
                            "Please provide a valid date in the future for the listing."
                          IncompleteTicketType ->
                            "One of the provided item types is incomplete."
                          NoTimeProvided ->
                            "Please provide a time for the listing."
                          RsvpError(_) ->
                            "A network error occurred while creating your listing. Please try again"
                          TimeParseError(_) ->
                            "Please provide a valid time in the future for the listing."
                          AttemptedToEditNonexistentListing ->
                            "The listing you are trying to edit does not exist."
                          InvalidId ->
                            "The listing ID contained within the URL is invalid."
                        }),
                      ]),
                    ]
                  }
                  option.None -> []
                }),
              ],
            ),
          ],
        )
    },
  ])
}
