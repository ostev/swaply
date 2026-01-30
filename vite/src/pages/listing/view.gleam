import gleam/int
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
import listing.{type Listing}
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
    listing: Option(Result(Listing, rsvp.Error)),
    delete_modal: Option(DeleteModal),
  )
}

pub type DeleteModal {
  DeleteModal(verify: String, error: Option(rsvp.Error))
}

pub fn init(listing_id: String) -> #(Model, Effect(Msg)) {
  #(
    Model(listing: option.None, delete_modal: option.None),
    listing.get(listing_id, ListingReceived),
  )
}

pub type Msg {
  ListingReceived(Result(Listing, rsvp.Error))
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
    ListingReceived(listing) -> #(
      Model(..model, listing: option.Some(listing)),
      effect.none(),
    )
    SetDeleteModal(delete_modal) -> {
      update_delete_modal(new: delete_modal, previous: model.delete_modal)
      #(Model(..model, delete_modal:), effect.none())
    }
    Delete -> {
      #(model, case model.listing {
        option.Some(Ok(listing)) ->
          listing.delete(listing.id, DeletedResponseReceived)
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

fn view_listing(listing: Listing) -> Element(Msg) {
  h.div([], [
    h.div([], [
      h.h2([], [h.text(listing.name)]),
      ui.tags(listing.tags),
      h.div([], [
        h.p([], [ui.datetime_view(listing.date)]),
        case listing.location {
          "" -> element.none()
          _ -> h.p([], [h.text(listing.location)])
        },
      ]),
      case listing.is_published {
        False -> h.span([], [h.text("Private")])
        True -> element.none()
      },
      case listing.short_description {
        "" -> element.none()
        _ -> h.p([], [h.text(listing.short_description)])
      },
    ]),

    h.div([], [
      case listing.description {
        "" ->
          h.p([], [
            h.text("The seller of this listing has provided no description."),
          ])
        _ -> h.p([], [h.text(listing.description)])
      },
    ]),
  ])
}

fn can_delete(model: Model) -> Bool {
  case model.delete_modal, model.listing {
    option.Some(delete_modal), option.Some(Ok(listing)) ->
      string.lowercase(delete_modal.verify) == string.lowercase(listing.name)
    _, _ -> False
  }
}

pub fn view(model: Model, shared: Shared) -> Element(Msg) {
  let can_delete = can_delete(model)

  h.div([], [
    case shared.user, model.listing {
      user.Authenticated(user), option.Some(Ok(listing))
        if user.is_admin && listing.is_published
      -> {
        h.p([], [
          h.text(
            "This is not your listing, but since you are able to edit and/or delete it
 for moderation purposes since you are an admin and it has been published.",
          ),
        ])
      }
      _, _ -> element.none()
    },
    h.dialog([a.id("delete_modal")], [
      h.p([], [
        h.text(
          "Please enter the name of the listing that you're about to delete to verify this action. "
          <> "Note that all items bought for this listing will be refunded.",
        ),
      ]),
      model.delete_modal
        |> option.map(fn(delete_modal) {
          case delete_modal.error {
            option.Some(_) ->
              h.p([], [
                h.text(
                  "There was an error while trying to delete your listing. Please try again.",
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
    h.div([], case model.listing {
      option.Some(result) -> {
        case result {
          Ok(listing) -> {
            [
              case shared.user {
                user.Authenticated(user)
                  if user.id == listing.seller.id
                  || { user.is_admin && listing.is_published }
                -> {
                  h.div([], [
                    h.a(
                      [
                        a.href(
                          "/listing/"
                          <> uri.percent_encode(listing.id)
                          <> "/edit",
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
              view_listing(listing),
            ]
          }
          Error(error) -> {
            [
              h.p([], [
                case error {
                  rsvp.HttpError(response) -> {
                    case response.status {
                      404 -> h.text("This listing does not exist.")
                      _ ->
                        h.text(
                          "An error occurred while loading the listing. Please try again.",
                        )
                    }
                  }
                  _ -> {
                    h.text(
                      "An error occurred while loading the listing. Please try again.",
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
