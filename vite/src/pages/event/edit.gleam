import event.{type Event}
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
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import modem
import rsvp
import shared.{type Shared}
import tempo
import tempo/date
import tempo/datetime
import tempo/error as tempo_error
import tempo/offset
import ui

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
    ticket_types: iv.Array(event.TicketTypeInput),
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
  AttemptedToEditNonexistentEvent
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
        ticket_types: iv.from_list([
          event.TicketTypeInput(name: "Standard", price: "", allotted: ""),
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
        effect.batch([check_auth, event.get(id, PrefillFormResponseReceived)])
    },
  )
}

pub type Msg {
  ResponseReceived(Result(Event, rsvp.Error))
  PrefillFormResponseReceived(Result(Event, rsvp.Error))

  UpdatedName(String)
  UpdatedDate(String)
  UpdatedTime(String)
  UpdatedShortDescription(String)
  UpdatedDescription(String)
  UpdatedLocation(String)
  UpdatedIsPublished(Bool)

  CreatedTags(List(String))
  DeletedTag(String)
  UpdatedTicketType(event.TicketTypeInput, index: Int)
  DeletedTicketType(index: Int)
  AddedTicketType(event.TicketTypeInput)
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

    UpdatedTicketType(ticket_type, index) -> {
      let ticket_types =
        model.form.ticket_types
        |> iv.set(index, ticket_type)
        |> result.unwrap(model.form.ticket_types)

      #(Model(..model, form: Form(..model.form, ticket_types:)), effect.none())
    }

    DeletedTicketType(index) -> {
      let ticket_types =
        model.form.ticket_types
        |> iv.delete(index)
        |> result.unwrap(model.form.ticket_types)

      #(Model(..model, form: Form(..model.form, ticket_types:)), effect.none())
    }

    AddedTicketType(ticket_type) -> {
      let ticket_types =
        model.form.ticket_types
        |> iv.append(ticket_type)

      #(Model(..model, form: Form(..model.form, ticket_types:)), effect.none())
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
    ResponseReceived(Ok(event)) -> {
      #(
        model,
        modem.push(
          "/event/" <> uri.percent_encode(event.id),
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

    PrefillFormResponseReceived(Ok(event)) -> {
      #(
        Model(..model, form: {
          let local_datetime = event.date |> datetime.to_offset(offset.local())

          Form(
            name: event.name,
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
            tags: set.from_list(event.tags),
            sorted_tags: event.tags |> list.sort(string.compare),
            ticket_types: iv.from_list(event.ticket_types)
              |> iv.map(fn(ticket_type) {
                event.TicketTypeInput(
                  name: ticket_type.name,
                  price: float.to_string(ticket_type.price),
                  allotted: int.to_string(ticket_type.allotted),
                )
              }),
            current_tag: "",
            is_published: event.is_published,
            short_description: event.short_description,
            description: event.description,
            location: event.location,
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
                404 -> AttemptedToEditNonexistentEvent
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

  use json_ticket_types <- result.try(
    form.ticket_types
    |> iv.to_list
    |> list.try_map(fn(ticket_type) {
      event.parse_ticket_type(ticket_type)
      |> result.map(event.ticket_type_to_json)
    })
    |> result.replace_error(IncompleteTicketType),
  )

  let body =
    json.object([
      #("name", json.string(form.name)),
      #("date", json.string(datetime |> datetime.format(tempo.ISO8601Seconds))),
      #("is_published", json.bool(form.is_published)),
      #("ticket_types", json.preprocessed_array(json_ticket_types)),
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
  let handler = rsvp.expect_json(event.decoder(), ResponseReceived)

  case mode {
    Create -> Ok(rsvp.post(event.api_prefix, body, handler))
    Update(id) -> {
      use uri <- result.try(
        rsvp.parse_relative_uri(event.url(id))
        |> result.replace_error(InvalidId),
      )
      use request <- result.try(
        request.from_uri(uri)
        |> result.replace_error(InvalidId),
      )

      Ok(rsvp.send(
        request
          |> request.set_method(http.Patch)
          |> request.set_body(json.to_string(body))
          |> request.set_header("content-type", "application/json"),
        handler,
      ))
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let date_is_valid = is_date_valid(model.form.date)

  h.div([], [
    case model.form.is_editable {
      False -> element.none()
      True ->
        h.form(
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
            ui.input(
              type_: "text",
              label: "Title",
              name: "name",
              value: option.Some(model.form.name),
              on_input: UpdatedName,
              is_valid: string.length(model.form.name) > 1,
            ),

            ui.input(
              type_: "date",
              label: "Date",
              name: "date",
              value: model.form.date,
              on_input: UpdatedDate,
              is_valid: date_is_valid,
            ),

            case date_is_valid {
              True -> element.none()
              False -> h.p([], [h.text("Please enter a date in the future.")])
            },

            ui.input(
              type_: "time",
              label: "Time",
              name: "time",
              value: model.form.time,
              on_input: UpdatedTime,
              is_valid: model.form.time
                |> option.map(is_time_valid)
                |> option.unwrap(False),
            ),

            ui.input(
              type_: "text",
              label: "Location",
              name: "location",
              value: option.Some(model.form.location),
              on_input: UpdatedLocation,
              is_valid: True,
            ),

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

            h.h3([], [h.text("Ticket types")]),

            h.div([], [
              h.div(
                [],
                model.form.ticket_types
                  |> iv.to_list
                  |> list.index_map(fn(ticket_type, index) {
                    h.div([], [
                      ui.ticket_type_input(
                        ticket_type,
                        "ticket_type_" <> int.to_string(index),
                        UpdatedTicketType(_, index:),
                      ),
                      h.button(
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

              h.button(
                [
                  a.type_("button"),
                  e.on_click(
                    AddedTicketType(event.TicketTypeInput(
                      name: "",
                      price: "",
                      allotted: "",
                    )),
                  ),
                ],
                [h.text("Add")],
              ),
            ]),

            ui.toggle_input(
              label: "Published?",
              name: "is_published",
              is_checked: model.form.is_published,
              on_input: UpdatedIsPublished,
            ),

            h.button([a.type_("submit")], [
              h.text(case model.mode {
                Create -> "Create"
                Update(_) -> "Update"
              }),
            ]),

            h.div([], case model.error {
              option.Some(error) -> {
                [
                  h.p([], [
                    h.text(case error {
                      ServerCreationError(server_response) -> {
                        case server_response {
                          InvalidName ->
                            "Please provide a name for the event that is longer than 3 characters."
                          NameAlreadyUsed ->
                            "An event with this name already exists."
                          Unauthorised -> "Please log in to create an event."
                        }
                      }

                      NoDateProvided -> {
                        "Please provide a date for the event."
                      }
                      DateParseError(_) ->
                        "Please provide a valid date in the future for the event."
                      IncompleteTicketType ->
                        "One of the provided ticket types is incomplete."
                      NoTimeProvided -> "Please provide a time for the event."
                      RsvpError(_) ->
                        "A network error occurred while creating your event. Please try again"
                      TimeParseError(_) ->
                        "Please provide a valid time in the future for the event."
                      AttemptedToEditNonexistentEvent ->
                        "The event you are trying to edit does not exist."
                      InvalidId ->
                        "The event ID contained within the URL is invalid."
                    }),
                  ]),
                ]
              }
              option.None -> []
            }),
          ],
        )
    },
  ])
}
