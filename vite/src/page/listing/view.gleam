import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/uri
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
import ui
import ui/colors
import ui/fonts
import ui/layout
import ui/listing as listing_ui
import ui/styles
import ui/tags
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
    option.None if modal_is_visible -> {
      set_dialog_visibility("delete_modal", False)
    }
    _ -> {
      Nil
    }
  }
}

pub fn update(shared: Shared, model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ListingReceived(listing) -> {
      case listing {
        Error(error) -> {
          io.println_error(
            "Error when fetching listing: " <> string.inspect(error),
          )
        }
        Ok(_) -> Nil
      }
      #(Model(..model, listing: option.Some(listing)), effect.none())
    }
    SetDeleteModal(delete_modal) -> {
      update_delete_modal(new: delete_modal, previous: model.delete_modal)
      #(Model(..model, delete_modal:), effect.none())
    }
    Delete -> {
      #(model, case model.listing {
        option.Some(Ok(listing)) ->
          listing.delete(
            listing.id,
            DeletedResponseReceived,
            with_token: shared.csrf_token,
          )
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
  h.div(
    css.class([
      css.max_width(length.rem(40.0)),
      css.width(length.vw(90)),
      css.margin_block(length.px(16)),
    ]),
    [],
    [
      h.div_([], [
        ui.h2_(listing.name),
        tags.tags(listing.tags),
        h.p(css.class([fonts.inter(), fonts.size_md()]), [], [
          h.span(styles.text_bold(), [], [h.text("Sold by ")]),
          h.span_([], [
            h.text(listing.seller.name <> " (" <> listing.seller.email <> ")"),
          ]),
        ]),
        h.div_([], [
          h.p(css.class([styles.detail()]), [], [
            listing_ui.datetime_view(listing.date),
          ]),
          case listing.location {
            "" -> element.none()
            _ -> h.p_([], [listing_ui.location(listing.location)])
          },
        ]),
        case listing.is_published {
          False -> h.span_([], [h.text("Private")])
          True -> element.none()
        },

        case listing.short_description {
          "" -> element.none()
          _ ->
            h.p(css.class([css.font_style("italic")]), [], [
              h.text(listing.short_description),
            ])
        },
      ]),

      h.div_([], [
        case listing.description {
          "" ->
            h.p_([], [
              h.text("The seller of this listing has provided no description."),
            ])
          _ -> h.p_([], [h.text(listing.description)])
        },
      ]),

      ui.h3_("Items for offer"),

      h.div(
        css.class([
          css.display("grid"),
          css.grid_template_columns("repeat(auto-fit, minmax(12rem, 1fr))"),
          css.gap(length.px(20)),
        ]),
        [],
        listing.items
          |> list.map(fn(item) {
            h.div(
              css.class([
                css.padding(length.px(10)),
                css.background_color(colors.primary_background),
                css.border_radius(length.px(10)),
              ]),
              [],
              [
                ui.labelled_pair("Name", item.name),
                ui.labelled_pair(
                  "Price",
                  "$"
                    <> {
                    item.price
                    |> float.to_precision(2)
                    |> float.to_string
                  },
                ),
                ui.labelled_pair("Quantity", int.to_string(item.quantity)),
              ],
            )
          }),
      ),
    ],
  )
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

  h.div(
    css.class([
      css.compose(layout.column(layout.Center)),
    ]),
    [],
    [
      case shared.user, model.listing {
        user.Authenticated(user), option.Some(Ok(listing))
          if user.is_admin && listing.is_published
        -> {
          ui.panel(
            ui.InfoPanel,
            True,
            "This is not your listing, but since you are able to edit and/or delete it
 for moderation purposes since you are an admin and it has been published.",
          )
        }
        _, _ -> element.none()
      },
      h.dialog(
        css.class([
          css.compose(styles.card()),
        ]),
        [
          a.id("delete_modal"),
          e.advanced(
            "close",
            decode.success(e.handler(SetDeleteModal(option.None), False, False)),
          ),
        ],
        [
          h.p(css.class([fonts.inter(), fonts.size_md()]), [], [
            h.text(
              "Please enter the name of the listing that you're about to delete to verify this action. ",
            ),
          ]),
          model.delete_modal
            |> option.map(fn(delete_modal) {
              case delete_modal.error {
                option.Some(_) ->
                  ui.panel(
                    ui.ErrorPanel,
                    True,
                    "There was an error while trying to delete your listing. Please try again.",
                  )
                option.None -> element.none()
              }
            })
            |> option.unwrap(element.none()),
          ui.input_(
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
          h.div(
            css.class([
              css.compose(layout.row(layout.End)),
              css.margin_top(length.px(12)),
              css.gap(length.px(12)),
            ]),
            [],
            [
              ui.button_with_attrs(
                ui.Primary,
                [
                  a.autofocus(True),
                ],
                "Cancel",
                SetDeleteModal(option.None),
              ),
              ui.button(
                case can_delete {
                  True -> ui.Danger
                  False -> ui.Disabled
                },
                "Delete",
                Delete,
              ),
            ],
          ),
        ],
      ),
      h.div_([], case model.listing {
        option.Some(result) -> {
          case result {
            Ok(listing) -> {
              [
                case shared.user {
                  user.Authenticated(user)
                    if user.id == listing.seller.id
                    || { user.is_admin && listing.is_published }
                  -> {
                    h.div(
                      css.class([
                        css.compose(layout.row(layout.End)),
                        css.gap(length.px(12)),
                      ]),
                      [],
                      [
                        ui.link_button(
                          ui.Primary,
                          text: "Edit",
                          to: "/listing/"
                            <> uri.percent_encode(listing.id)
                            <> "/edit",
                        ),

                        ui.button(
                          ui.Danger,
                          "Delete",
                          SetDeleteModal(
                            option.Some(DeleteModal(
                              error: option.None,
                              verify: "",
                            )),
                          ),
                        ),
                      ],
                    )
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
                ui.panel(ui.ErrorPanel, True, case error {
                  rsvp.HttpError(response) -> {
                    case response.status {
                      404 -> "This listing does not exist."
                      401 ->
                        "You do not have permission to access this listing."
                      _ ->
                        "An error occurred while loading the listing. Please try again."
                    }
                  }
                  _ ->
                    "An error occurred while loading the listing. Please try again."
                }),
              ]
            }
          }
        }
        option.None -> {
          [element.none()]
        }
      }),
    ],
  )
}
