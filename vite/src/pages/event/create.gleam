import event
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
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
import rsvp
import tempo
import tempo/date
import tempo/datetime
import tempo/error as tempo_error
import tempo/offset
import tempo/time
import ui

pub type Model {
  Model(form: Form, error: Option(rsvp.Error))
}

pub type Form {
  Form(
    name: String,
    date: Option(String),
    time: Option(String),
    tags: Set(String),
    sorted_tags: List(String),
    current_tag: String,
    ticket_types: iv.Array(event.TicketType),
    is_published: Bool,
  )
}

pub fn init() -> #(Model, Effect(msg)) {
  #(
    Model(
      form: Form(
        name: "",
        date: option.None,
        time: option.None,
        tags: set.new(),
        sorted_tags: [],
        ticket_types: iv.new(),
        current_tag: "",
        is_published: False,
      ),
      error: option.None,
    ),
    effect.none(),
  )
}

pub type Msg {
  CreateResponseReceived(Result(Response(String), rsvp.Error))
  UpdatedName(String)
  UpdatedDate(String)
  UpdatedTime(String)
  CreatedTags(List(String))
  DeletedTag(String)
  UpdatedTicketType(event.TicketType, index: Int)
  DeletedTicketType(index: Int)
  AddedTicketType(event.TicketType)
  UpdateCurrentTag(String)
  SubmitForm
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
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
        Model(..model, form: Form(..model.form, date: option.Some(time))),
        effect.none(),
      )
    }
    UpdateCurrentTag(current_tag) -> {
      #(Model(..model, form: Form(..model.form, current_tag:)), effect.none())
    }
    CreatedTags(new_tags) -> {
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
      create(model.form)
      |> result.map(fn(create_effect) { #(model, create_effect) })
      |> result.unwrap(#(model, effect.none()))
    }
    CreateResponseReceived(Ok(_)) -> {
      #(model, modem.push("/my/events", option.None, option.None))
    }
    CreateResponseReceived(Error(error)) -> {
      #(Model(..model, error: option.Some(error)), effect.none())
    }
  }
}

fn parse_date(
  date_string: String,
) -> Result(tempo.Date, tempo_error.DateParseError) {
  date_string
  |> date.parse(tempo.ISO8601Date)
}

fn is_date_valid(date_string: String) -> Bool {
  case parse_date(date_string) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn parse_time(
  time_string: String,
) -> Result(tempo.Time, tempo_error.TimeParseError) {
  time_string
  |> time.parse_any
}

fn is_time_valid(time_string: String) -> Bool {
  case parse_time(time_string) {
    Ok(_) -> True
    Error(_) -> False
  }
}

type CreationError {
  NoDateProvided
  NoTimeProvided
  DateParseError(tempo_error.DateParseError)
  TimeParseError(tempo_error.TimeParseError)
}

fn get_datetime(
  date: Option(String),
  time: Option(String),
) -> Result(tempo.DateTime, CreationError) {
  date
  |> option.to_result(NoDateProvided)
  |> result.map(fn(date_string) {
    parse_date(date_string)
    |> result.map_error(DateParseError)
    |> result.map(fn(date) {
      time
      |> option.to_result(NoTimeProvided)
      |> result.map(fn(time_string) {
        parse_time(time_string)
        |> result.map_error(TimeParseError)
      })
      |> result.flatten
      |> result.map(datetime.new(date, _, offset.local()))
    })
    |> result.flatten
  })
  |> result.flatten
}

fn create(form: Form) -> Result(Effect(Msg), CreationError) {
  get_datetime(form.date, form.time)
  |> result.map(fn(datetime) {
    let body =
      json.object([
        #("is_published", json.bool(form.is_published)),
        #("name", json.string(form.name)),
        #(
          "date",
          json.string(datetime |> datetime.format(tempo.ISO8601Seconds)),
        ),
        #(
          "ticket_types",
          json.preprocessed_array(
            form.ticket_types |> iv.map(event.ticket_type_to_json) |> iv.to_list,
          ),
        ),
      ])
    let handler = rsvp.expect_ok_response(CreateResponseReceived)

    let request =
      request.new()
      |> request.set_path(event.api_prefix)
      |> request.set_method(http.Post)
      |> request.set_body(json.to_string(body))
      |> request.set_header("content-type", "application/json")

    rsvp.send(request, handler)
  })
}

pub fn view(model: Model) -> Element(Msg) {
  h.div([], [
    h.form([e.on_submit(fn(_) { SubmitForm })], [
      ui.input(
        type_: "text",
        label: "Title",
        name: "name",
        value: option.Some(model.form.name),
        on_input: UpdatedName,
        is_valid: string.length(model.form.name) > 2,
      ),

      ui.input(
        type_: "date",
        label: "Date",
        name: "date",
        value: model.form.date,
        on_input: UpdatedDate,
        is_valid: model.form.date
          |> option.map(is_date_valid)
          |> option.unwrap(False),
      ),

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
                h.button([e.on_click(DeletedTicketType(index))], [
                  h.text("Delete"),
                ]),
              ])
            }),
        ),

        h.button(
          [
            e.on_click(
              AddedTicketType(event.TicketType(
                name: "",
                price: 10.0,
                allotted: 5,
              )),
            ),
          ],
          [h.text("Add")],
        ),
      ]),

      h.button([a.type_("submit"), e.on_click(SubmitForm)], [
        h.text("Create"),
      ]),

      h.div([], case model.error {
        option.Some(_) -> {
          [h.p([], [h.text("Error creating your event. Please try again.")])]
        }
        option.None -> []
      }),
    ]),
  ])
}
