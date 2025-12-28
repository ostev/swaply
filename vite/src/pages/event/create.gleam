import event
import extra/list as extra_list
import extra/time
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri.{type Uri}
import iv
import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/event as e
import modem
import pages/auth
import pages/auth/user.{type User}
import rsvp
import shared.{type Shared}
import tempo
import tempo/date
import tempo/datetime
import tempo/error as tempo_error
import tempo/offset
import tempo/time as tempo_time
import ui

pub type Model {
  Model(form: Form, error: Option(CreationError))
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
  )
}

pub type CreationError {
  NoDateProvided
  NoTimeProvided
  DateParseError(tempo_error.DateParseError)
  TimeParseError(time.ParseError)
  IncompleteTicketType
  ServerCreationError(ServerResponse)
  RsvpError(rsvp.Error)
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

pub fn init(shared_model: Shared) -> #(Model, Effect(msg)) {
  #(
    Model(
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
      ),
      error: option.None,
    ),
    shared.check_authentication(shared_model),
  )
}

pub type Msg {
  CreateResponseReceived(Result(Response(String), rsvp.Error))
  UpdatedName(String)
  UpdatedDate(String)
  UpdatedTime(String)
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

    SubmitForm -> {
      case create(model.form) {
        Ok(create_effect) -> #(model, create_effect)
        Error(error) -> #(
          Model(..model, error: option.Some(error)),
          effect.none(),
        )
      }
    }
    CreateResponseReceived(Ok(_)) -> {
      #(model, modem.push("/my/events", option.None, option.None))
    }
    CreateResponseReceived(Error(error)) -> {
      #(
        Model(
          ..model,
          error: option.Some(case error {
            rsvp.HttpError(response) -> {
              json.parse(response.body, server_response_decoder())
              |> result.map(ServerCreationError)
              |> result.unwrap(RsvpError(error))
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
  case time.parse(time_string) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn get_datetime(
  date: Option(String),
  time: Option(String),
) -> Result(tempo.DateTime, CreationError) {
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
    time.parse(time_string)
    |> result.map_error(TimeParseError),
  )
  Ok(datetime.new(date, time, offset.local()))
}

fn create(form: Form) -> Result(Effect(Msg), CreationError) {
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
      #("is_published", json.bool(form.is_published)),
      #("name", json.string(form.name)),
      #("date", json.string(datetime |> datetime.format(tempo.ISO8601Seconds))),
      #("ticket_types", json.preprocessed_array(json_ticket_types)),
    ])
  let handler = rsvp.expect_ok_response(CreateResponseReceived)

  Ok(rsvp.post(event.api_prefix, body, handler))
}

pub fn view(model: Model) -> Element(Msg) {
  let date_is_valid = is_date_valid(model.form.date)

  h.div([], [
    h.form(
      [
        e.on_submit(fn(_) { SubmitForm }),
        e.advanced("keydown", {
          use key <- decode.field("key", decode.string)

          decode.success(case key {
            "Enter" ->
              e.handler(NoOp, prevent_default: True, stop_propagation: False)
            _ ->
              e.handler(NoOp, prevent_default: False, stop_propagation: False)
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
                    [e.on_click(DeletedTicketType(index)), a.type_("button")],
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

        h.button([a.type_("submit")], [
          h.text("Create"),
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
                }),
              ]),
            ]
          }
          option.None -> []
        }),
      ],
    ),
  ])
}
