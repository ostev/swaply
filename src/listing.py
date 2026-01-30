from datetime import UTC, datetime
from enum import Enum
from functools import reduce
import json
from multiprocessing import Value
from sqlite3 import Connection, Cursor
import timeit
import aenum
from flask import Blueprint, current_app, request

from api import API_PREFIX
from auth.session import authenticated, protected
from auth.user import User
from auth.user_api import UserData, authenticated_with_user, protected_with_user
from db.schema import Column, PrimaryKey, table
from utils import normalise_json_str_array, result
import globals


@table
class Listing:
    table_name = "listings"
    id = PrimaryKey.integer().autoincrement()
    seller = Column.foreign(User.id)

    # 0 is not published, 1 is published
    # (since SQLLite doesn't have a boolean type)
    is_published = Column.integer()

    name = Column.text()
    date = Column.text()

    short_description = Column.text()
    description = Column.text()

    # "" represents no location
    location = Column.text()

    # Stored as a comma-seperated list
    tags = Column.text()


@table
class TicketType:
    table_name = "items"
    id = PrimaryKey.integer().autoincrement()
    listing = Column.foreign(Listing.id)

    name = Column.text()
    price = Column.numeric()
    quantity = Column.integer()


listing_api = Blueprint("listings", __name__, url_prefix=API_PREFIX + "/listings")


class ListingResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    SUCCESS = 200
    NOT_FOUND = 404
    UNAUTHORISED = 401
    INVALID_NAME = 400
    NAME_ALREADY_USED = 400


@listing_api.route("/search")
@authenticated
def search_listings(user_id: int | None):
    search_query = request.args.get("q", "")
    page = int(request.args.get("p", 0))
    filter_owned = request.args.get("filter_owned", "false").lower() == "true"

    results_per_page = 10

    is_authorized_expr = (
        "(listings.is_published = 1 OR seller = :user_id)"
        if user_id is not None
        else "listings.is_published = 1"
    )

    filter_expr = (
        "seller = :user_id AND" if (user_id is not None) and filter_owned else ""
    )

    search_query_expr = (
        f"listing_search_index MATCH :query AND" if len(search_query) >= 3 else ""
    )

    condition_expr = f"{search_query_expr} {filter_expr} {is_authorized_expr}"
    params = {
        "query": search_query,
        "results_per_page": results_per_page,
        "offset": page * results_per_page,
    } | ({"user_id": user_id} if user_id is not None else {})

    def retrieve_listings_with_items(conn: Connection, cursor: Cursor):

        return (
            cursor.execute(
                f"""
                SELECT
                    listings.id,
                    listings.name,
                    listings.seller,
                    listings.date,
                    listings.is_published,
                    listings.tags,
                    listings.short_description,
                    listings.description,
                    listings.location
                FROM listing_search_index
                JOIN listings
                    ON listing_search_index.ROWID = listings.id AND ({condition_expr})
                LIMIT :results_per_page OFFSET :offset
                """,
                params,
            ).fetchall(),
            cursor.execute(
                f"""
                SELECT COUNT(listings.id)
                FROM listing_search_index
                JOIN listings
                    ON listing_search_index.ROWID = listings.id AND ({condition_expr})
                """,
                params,
            ).fetchone()[0],
        )

    (listing_tuples, count) = globals.db.run(retrieve_listings_with_items)

    listings = []

    for listing in listing_tuples:
        (
            id,
            name,
            seller_id,
            date,
            is_published,
            tags,
            short_description,
            description,
            location,
        ) = listing

        tickets = [
            {
                "name": str(ticket_name),
                "price": float(ticket_price),
                "quantity": int(ticket_quantity),
            }
            for ticket_name, ticket_price, ticket_quantity in globals.db.retrieve_all(
                [TicketType.name, TicketType.price, TicketType.quantity],
                TicketType.listing,
                id,
            )
        ]

        (seller_email,) = globals.db.retrieve([User.email], User.id, seller_id)  # type: ignore

        listings.append(
            {
                "id": str(id),
                "name": str(name),
                "seller": {"id": str(seller_id), "email": seller_email},
                "date": datetime.fromisoformat(date).isoformat(),
                "is_published": bool(is_published),
                "tags": tags_from_csv(tags),
                "items": tickets,
                "short_description": str(short_description),
                "description": str(description),
                "location": str(location),
            }
        )

    return {"listings": listings, "number_of_pages": count // results_per_page}


def tags_from_csv(tag_string: str) -> list[str]:
    return [
        stripped_tag
        for tag in str(tag_string).split(",")
        if (stripped_tag := tag.strip())
    ]


def get_items() -> list[tuple[str, float, int]]:
    return [
        (
            str(ticket_type["name"]),
            float(ticket_type["price"]),
            int(ticket_type["quantity"]),
        )
        for ticket_type in request.json.get("items", [])
    ]


def insert_items(cursor: Cursor, listing_id: int, items: list[tuple[str, float, int]]):
    cursor.executemany(
        "INSERT INTO items (listing, name, price, quantity) VALUES (?, ?, ?, ?)",
        [(listing_id,) + ticket_type for ticket_type in items],
    )


@listing_api.route("/", methods=["POST"])
@protected
def create_listing(user_id: int):
    name = str(request.json["name"])
    if len(name) < 3:
        return result(ListingResult.INVALID_NAME)

    if globals.db.run(
        lambda _, cursor: cursor.execute(
            "SELECT id FROM listings WHERE name LIKE ?", (name,)
        ).fetchone()
        is not None
    ):
        return result(ListingResult.NAME_ALREADY_USED)

    date = datetime.fromisoformat(str(request.json["date"])).astimezone(UTC)

    is_published = bool(request.json.get("is_published", False))
    items = get_items()

    tags = [str(tag) for tag in request.json.get("tags", [])]
    tag_string = ",".join(tags)

    short_description = request.json["short_description"]
    description = request.json["description"]

    location = request.json["location"]

    def insert_listing(conn: Connection, cursor: Cursor):
        cursor.execute(
            "INSERT INTO listings (name, date, is_published, seller, tags, short_description, description, location) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                name,
                date,
                is_published,
                user_id,
                tag_string,
                short_description,
                description,
                location,
            ),
        )

        if cursor.lastrowid is None:
            raise ValueError("Failed to create listing")

        listing_id = int(cursor.lastrowid)
        insert_items(cursor, listing_id, items)

        conn.commit()

        return listing_id

    listing_id = globals.db.run(insert_listing)

    return get_listing(listing_id)  # type: ignore


@listing_api.route("/<listing_id>", methods=["GET"])
@authenticated
def get_listing(user_id: int | None, listing_id: int):
    maybe_listing = globals.db.retrieve(
        [
            Listing.name,
            Listing.seller,
            Listing.date,
            Listing.is_published,
            Listing.tags,
            Listing.short_description,
            Listing.description,
            Listing.location,
        ],
        Listing.id,
        listing_id,
    )

    if maybe_listing is not None:
        (
            name,
            seller_id,
            date,
            is_published,
            tag_string,
            short_description,
            description,
            location,
        ) = maybe_listing

        items = [
            {"name": str(name), "price": float(price), "quantity": int(quantity)}
            for (name, price, quantity) in globals.db.retrieve_all(
                [TicketType.name, TicketType.price, TicketType.quantity],
                TicketType.listing,
                listing_id,
            )
        ]

        (seller_email,) = globals.db.retrieve([User.email], User.id, seller_id)  # type: ignore

        if is_published or (user_id is not None and int(seller_id) == user_id):
            return {
                "id": str(listing_id),
                "name": str(name),
                "seller": {"id": str(seller_id), "email": str(seller_email)},
                "date": datetime.fromisoformat(date).isoformat(),
                "is_published": bool(is_published),
                "tags": tags_from_csv(tag_string),
                "short_description": str(short_description),
                "description": str(description),
                "location": str(location),
                "items": items,
            }
        else:
            return result(ListingResult.UNAUTHORISED)
    else:
        return result(ListingResult.NOT_FOUND)


@listing_api.route("/<listing_id>", methods=["PATCH"])
@protected_with_user
def update_listing(user: UserData, listing_id: str):
    listing_id_parsed = int(listing_id)

    listing_details = globals.db.retrieve(
        [Listing.seller, Listing.is_published], Listing.id, listing_id_parsed
    )

    if listing_details == None:
        return result(ListingResult.NOT_FOUND)

    seller_id, is_listing_already_published = listing_details

    # Admins can only update published listings
    if user.id != seller_id and not (user.is_admin and is_listing_already_published):
        return result(ListingResult.UNAUTHORISED)

    if "name" in request.json:
        name = str(request.json["name"])

        if len(name) < 3:
            return result(ListingResult.INVALID_NAME)
    else:
        name = None

    if "date" in request.json:
        date = str(datetime.fromisoformat(str(request.json["date"])).astimezone(UTC))
    else:
        date = None

    if "is_published" in request.json:
        is_published = bool(request.json["is_published"])
    else:
        is_published = None

    fields: dict[str, str | int] = (
        {
            "id": listing_id_parsed,
        }
        | ({"name": name} if name is not None else {})
        | ({"date": date} if date is not None else {})
        | ({"is_published": is_published} if is_published is not None else {})
    )

    if "items" in request.json:
        items = get_items()
    else:
        items = None

    placeholders = ", ".join([f"{column} = :{column}" for column in fields.keys()])

    def insert_listing(conn: Connection, cursor: Cursor):
        cursor.execute(f"UPDATE listings SET {placeholders} WHERE id = :id", fields)

        if items is not None:
            cursor.execute("DELETE FROM items WHERE listing = ?", (listing_id,))
            if len(items) > 0:
                insert_items(cursor, listing_id_parsed, items)

        conn.commit()

    globals.db.run(insert_listing)

    return get_listing(listing_id_parsed)  # type: ignore


@listing_api.route("/<listing_id>", methods=["DELETE"])
@protected_with_user
def delete_listing(user: UserData, listing_id: str):
    listing_id_parsed = int(listing_id)

    seller = globals.db.retrieve([Listing.seller], Listing.id, listing_id_parsed)

    if seller is not None and (seller[0] == user.id or user.is_admin):
        # TODO: check and refund transactions
        def run_delete(conn: Connection, cursor: Cursor):
            cursor.execute(
                "DELETE FROM listings WHERE listing_id = ?", (listing_id_parsed,)
            )
            conn.commit()

        globals.db.run(run_delete)

        return result(ListingResult.SUCCESS)
    else:
        return result(ListingResult.UNAUTHORISED)
