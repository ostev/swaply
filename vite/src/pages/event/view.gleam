import event.{type Event}
import gleam/int
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
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
import tempo/offset
import ui
import user

pub type Model {
  Model(
    event: Option(Result(Event, rsvp.Error)),
    delete_modal: Option(DeleteModal),
  )
}

pub type DeleteModal {
  DeleteModal(verify: String, error: Option(rsvp.Error))
}

pub fn init(event_id: String) -> #(Model, Effect(Msg)) {
  #(
    Model(event: option.None, delete_modal: option.None),
    event.get(event_id, EventReceived),
  )
}

pub type Msg {
  EventReceived(Result(Event, rsvp.Error))
  SetDeleteModal(Option(DeleteModal))
  Delete
  DeletedResponseReceived(Result(Nil, rsvp.Error))
}

@external(javascript, "./dialog.mjs", "set_dialog_visibility")
pub fn set_dialog_visibility(id: String, is_visible: Bool) -> Nil

fn update_delete_modal(
  new new: Option(DeleteModal),
  previous previous: Option(DeleteModal),
) {
  let modal_is_visible = option.is_some(previous)
  case new {
    option.Some(_) if !modal_is_visible -> {
      set_dialog_visibility("delete_modal", True)
    }
    option.None if modal_is_visible ->
      set_dialog_visibility("delete_modal", True)
    _ -> {
      Nil
    }
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    EventReceived(event) -> #(
      Model(..model, event: option.Some(event)),
      effect.none(),
    )
    SetDeleteModal(delete_modal) -> {
      update_delete_modal(new: delete_modal, previous: model.delete_modal)
      #(Model(..model, delete_modal:), effect.none())
    }
    Delete -> {
      #(model, case model.event {
        option.Some(Ok(event)) ->
          event.delete(event.id, DeletedResponseReceived)
          |> result.unwrap(effect.none())
        _ -> effect.none()
      })
    }
    DeletedResponseReceived(response) -> {
      case response {
        Ok(_) -> #(model, modem.push("/", option.None, option.None))
        Error(error) -> #(
          Model(
            ..model,
            delete_modal: model.delete_modal
              |> option.map(fn(delete_modal) {
                DeleteModal(..delete_modal, error: option.Some(error))
              }),
          ),
          effect.none(),
        )
      }
    }
  }
}

fn view_event(event: Event) -> Element(Msg) {
  h.div([], [
    h.div([], [
      h.h2([], [h.text(event.name)]),
      ui.tags(event.tags),
      h.div([], [
        h.p([], [ui.datetime_view(event.date)]),
        case event.location {
          "" -> element.none()
          _ -> h.p([], [h.text(event.location)])
        },
      ]),
      case event.is_published {
        False -> h.span([], [h.text("Private")])
        True -> element.none()
      },
      case event.short_description {
        "" -> element.none()
        _ -> h.p([], [h.text(event.short_description)])
      },
    ]),

    h.div([], [
      case event.description {
        "" ->
          h.p([], [
            h.text("The manager of this event has provided no description."),
          ])
        _ -> h.p([], [h.text(event.description)])
      },
    ]),
  ])
}

fn can_delete(model: Model) -> Bool {
  case model.delete_modal, model.event {
    option.Some(delete_modal), option.Some(Ok(event)) ->
      string.lowercase(delete_modal.verify) == string.lowercase(event.name)
    _, _ -> False
  }
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  let can_delete = can_delete(model)

  h.div([], [
    case shared.user, model.event {
      user.Authenticated(user), option.Some(Ok(event))
        if user.is_admin && event.is_published
      -> {
        h.p([], [
          h.text(
            "This is not your event, but since you are able to edit and/or delete it
 for moderation purposes since you are an admin and it has been published.",
          ),
        ])
      }
      _, _ -> element.none()
    },
    h.dialog([a.id("delete_modal")], [
      h.p([], [
        h.text(
          "Please enter the name of the event that you're about to delete to verify this action. "
          <> "Note that all tickets bought for this event will be refunded.",
        ),
      ]),
      model.delete_modal
        |> option.map(fn(delete_modal) {
          case delete_modal.error {
            option.Some(_) ->
              h.p([], [
                h.text(
                  "There was an error while trying to delete your event. Please try again.",
                ),
              ])
            option.None -> element.none()
          }
        })
        |> option.unwrap(element.none()),
      ui.input(
        label: "Name",
        type_: "text",
        name: "delete_modal_verify",
        value: model.delete_modal
          |> option.map(fn(delete_modal) { delete_modal.verify }),
        on_input: fn(value) {
          SetDeleteModal(
            option.Some(DeleteModal(
              error: model.delete_modal
                |> option.then(fn(delete_modal) { delete_modal.error }),
              verify: value,
            )),
          )
        },
        is_valid: can_delete,
      ),
      h.button(
        [
          a.type_("button"),
          a.autofocus(True),
          e.on_click(SetDeleteModal(option.None)),
        ],
        [h.text("Cancel")],
      ),
      h.button(
        [
          a.type_("button"),
          a.autofocus(True),
          a.classes([#("disabled", !can_delete)]),
          e.on_click(Delete),
        ],
        [h.text("Delete")],
      ),
    ]),
    h.div([], case model.event {
      option.Some(result) -> {
        case result {
          Ok(event) -> {
            [
              case shared.user {
                user.Authenticated(user)
                  if user.id == event.manager
                  || { user.is_admin && event.is_published }
                -> {
                  h.div([], [
                    h.a(
                      [
                        a.href(
                          "/event/" <> uri.percent_encode(event.id) <> "/edit",
                        ),
                      ],
                      [h.text("Edit")],
                    ),
                    h.button(
                      [
                        a.type_("Button"),
                        e.on_click(
                          SetDeleteModal(
                            option.Some(DeleteModal(
                              error: option.None,
                              verify: "",
                            )),
                          ),
                        ),
                      ],
                      [
                        h.text("Delete"),
                      ],
                    ),
                  ])
                }
                _ -> {
                  element.none()
                }
              },
              view_event(event),
            ]
          }
          Error(error) -> {
            [
              h.p([], [
                case error {
                  rsvp.HttpError(response) -> {
                    case response.status {
                      404 -> h.text("This event does not exist.")
                      _ ->
                        h.text(
                          "An error occurred while loading the event. Please try again.",
                        )
                    }
                  }
                  _ -> {
                    h.text(
                      "An error occurred while loading the event. Please try again.",
                    )
                  }
                },
              ]),
            ]
          }
        }
      }
      option.None -> {
        [element.none()]
      }
    }),
  ])
}
