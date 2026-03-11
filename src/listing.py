from datetime import UTC, datetime
from enum import Enum
from functools import reduce
import json
from multiprocessing import Value
from sqlite3 import Connection, Cursor
import timeit
from typing import Any, Optional
import aenum
from flask import Blueprint, current_app, request

from api import API_PREFIX
from auth.session import authenticated, protected
from auth.user import User
from auth.user_api import UserData, authenticated_with_user, protected_with_user
from db.schema import Column, PrimaryKey, table
from utils import error, normalise_json_str_array, result
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
class Item:
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

    INVALID_NAME = 422
    INVALID_SHORT_DESCRIPTION = 422
    INVALID_DESCRIPTION = 422
    INVALID_LOCATION = 422
    INVALID_PRICING = 422
    INVALID_QUANTITY = 422
    TOO_MANY_TAGS = 422
    TOO_MANY_ITEMS = 422
    NAME_ALREADY_USED = 422
    DATE_IN_PAST = 422


def create_search_index(conn: Connection, cursor: Cursor):
    """
    Initialises the SQLite full-text search table for listings, with triggers to update it
    if the backing listings table changes.
    """

    cursor.executescript(
        """
        CREATE VIRTUAL TABLE IF NOT EXISTS listing_search_index
            USING fts5(
                name,
                tags,
                description,
                short_description,
                location,
                content="listings",
                content_rowid="id",
                tokenize="trigram"
            );

        CREATE TRIGGER IF NOT EXISTS listing_insert_trigger AFTER INSERT ON listings BEGIN
            INSERT INTO
                listing_search_index(
                    rowid,
                    name,
                    tags,
                    description,
                    short_description,
                    location
                )
                VALUES (
                    NEW.id,
                    NEW.name,
                    NEW.tags,
                    NEW.description,
                    NEW.short_description,
                    NEW.location
                );
        END;

        CREATE TRIGGER IF NOT EXISTS listing_delete_trigger AFTER DELETE ON listings BEGIN
            INSERT INTO
                listing_search_index(
                    listing_search_index,
                    rowid,
                    name,
                    tags,
                    description,
                    short_description,
                    location
                )
                VALUES (
                    "delete",
                    OLD.id,
                    OLD.name,
                    OLD.tags,
                    OLD.description,
                    OLD.short_description,
                    OLD.location
                );
        END;

        CREATE TRIGGER IF NOT EXISTS listing_update_trigger AFTER UPDATE ON listings BEGIN
            INSERT INTO
                listing_search_index(
                    listing_search_index,
                    rowid,
                    name,
                    tags,
                    description,
                    short_description,
                    location
                )
                VALUES (
                    "delete",
                    OLD.id,
                    OLD.name,
                    OLD.tags,
                    OLD.description,
                    OLD.short_description,
                    OLD.location
                );

            INSERT INTO
                listing_search_index(
                    rowid,
                    name,
                    tags,
                    description,
                    short_description,
                    location
                )
                VALUES (
                    NEW.id,
                    NEW.name,
                    NEW.tags,
                    NEW.description,
                    NEW.short_description,
                    NEW.location
                );
        END;
        """
    )
    conn.commit()


@listing_api.route("/search")
@authenticated
def search_listings(user_id: int | None):
    """
    Searches for a listing by a set of filters.
    """

    search_query = request.args.get("q", "")
    page = int(request.args.get("p", 0))
    filter_owned = request.args.get("filter_owned", "false").lower() == "true"

    results_per_page = 10

    is_authorized_expr = (
        "((listings.is_published = 1 AND date > datetime('now')) OR seller = :user_id)"
        if user_id is not None
        else "(listings.is_published = 1 AND date > datetime('now'))"
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
        # This loop transforms the results from the relational database in a
        # structured, document-oriented JSON format.
        if (parsed := parse_listing(listing, check_date=False)) is not None:
            listings.append(parsed)

    return {"listings": listings, "number_of_pages": count // results_per_page}


def parse_listing(listing, check_date: bool) -> Optional[dict[str, Any]]:
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

    parsed_date = datetime.fromisoformat(date).astimezone(UTC)

    if check_date and parsed_date <= datetime.now(UTC):
        error(ListingResult.UNAUTHORISED)

    tickets = [
        {
            "name": str(ticket_name),
            "price": float(ticket_price),
            "quantity": int(ticket_quantity),
        }
        for ticket_name, ticket_price, ticket_quantity in globals.db.retrieve_all(
            [Item.name, Item.price, Item.quantity],
            Item.listing,
            id,
        )
    ]

    seller_columns = globals.db.retrieve([User.email, User.name], User.id, seller_id)

    if seller_columns is None:
        return None

    (seller_email, seller_name) = seller_columns

    return {
        "id": str(id),
        "name": str(name),
        "seller": {
            "id": str(seller_id),
            "email": str(seller_email),
            "name": seller_name,
        },
        "date": datetime.fromisoformat(date).isoformat(),
        "is_published": bool(is_published),
        "tags": tags_from_csv(tags),
        "items": tickets,
        "short_description": str(short_description),
        "description": str(description),
        "location": str(location),
    }


def tags_from_csv(tag_string: str) -> list[str]:
    """
    Utility function to convert the list of tags as stored as comma-seperated
    values in the database to a list of strings.
    """
    return [
        stripped_tag
        for tag in str(tag_string).split(",")
        if (stripped_tag := tag.strip())
    ]


def validate_item(item):
    """
    Checks whether an item being sold meets the minimum requirements.
    """
    name = str(item["name"]).strip()
    price = float(item["price"])
    quantity = int(item["quantity"])

    if price < 0 or price > 1e6:
        error(ListingResult.INVALID_PRICING)

    if quantity < 0 or quantity > 1e6:
        error(ListingResult.INVALID_QUANTITY)

    if len(name) == 0:
        error(ListingResult.INVALID_NAME)

    return (name, price, quantity)


def get_items() -> list[tuple[str, float, int]]:
    """
    Get the items from the JSON request body
    """
    return [validate_item(item) for item in request.json.get("items", [])]


def insert_items(cursor: Cursor, listing_id: int, items: list[tuple[str, float, int]]):
    """
    Insert items into the database
    """
    cursor.executemany(
        "INSERT INTO items (listing, name, price, quantity) VALUES (?, ?, ?, ?)",
        [(listing_id,) + ticket_type for ticket_type in items],
    )


def validate_listing_fields(is_unique: bool):
    """
    Validate and parse a listing JSON body
    """
    name = str(request.json["name"]).strip()
    if len(name) < 3 or len(name) > 30:
        error(ListingResult.INVALID_NAME)

    if is_unique and globals.db.run(
        lambda _, cursor: cursor.execute(
            "SELECT id FROM listings WHERE name LIKE ?", (name,)
        ).fetchone()
        is not None
    ):
        error(ListingResult.NAME_ALREADY_USED)

    date = datetime.fromisoformat(str(request.json["date"])).astimezone(UTC)

    if date <= datetime.now(UTC):
        error(ListingResult.DATE_IN_PAST)

    is_published = bool(request.json.get("is_published", False))

    if len(raw_tags := request.json.get("tags", [])) > 6:
        error(ListingResult.TOO_MANY_TAGS)
    else:
        tags = [str(tag) for tag in raw_tags]
        tag_string = ",".join(tags)

    short_description = str(request.json["short_description"]).strip()

    if len(short_description) < 3 or len(short_description) > 300:
        error(ListingResult.INVALID_SHORT_DESCRIPTION)

    description = str(request.json["description"]).strip()

    if len(description) < 3 or len(description) > 10_000:
        error(ListingResult.INVALID_DESCRIPTION)

    location = str(request.json["location"]).strip()

    if len(location) < 3 or len(location) > 200:
        error(ListingResult.INVALID_LOCATION)

    return {
        "name": name,
        "date": str(date),
        "short_description": short_description,
        "description": description,
        "is_published": is_published,
        "tags": tag_string,  # type: ignore
        "location": location,
    }


@listing_api.route("/", methods=["POST"])
@protected
def create_listing(user_id: int):
    """
    Creates a listing for the authenticated user with the given fields.
    """

    fields = validate_listing_fields(is_unique=True)
    items = get_items()

    if len(items) > 20:
        return result(ListingResult.TOO_MANY_ITEMS)

    def insert_listing(conn: Connection, cursor: Cursor):
        cursor.execute(
            "INSERT INTO listings (name, date, is_published, seller, tags, short_description, description, location) VALUES (:name, :date, :is_published, :seller, :tags, :short_description, :description, :location)",
            fields
            | {
                "seller": user_id,
            },
        )

        if cursor.lastrowid is None:
            raise ValueError("Failed to create listing")

        listing_id = int(cursor.lastrowid)
        insert_items(cursor, listing_id, items)

        conn.commit()

        return listing_id

    listing_id = globals.db.run(insert_listing)

    return {"id": str(listing_id)}


@listing_api.route("/<listing_id>", methods=["GET"])
@authenticated
def get_listing(user_id: int | None, listing_id: int):
    """
    Retrieves a listing from the database
    """

    def retrieve_listing(conn: Connection, cursor: Cursor):
        return cursor.execute(
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
            WHERE listings.id = ? AND ({"listings.seller = ? OR " if user_id is not None else ""}is_published = 1)
        """,
            (listing_id, user_id),
        ).fetchone()

    maybe_listing = globals.db.run(retrieve_listing)

    if maybe_listing is not None:
        if (parsed := parse_listing(maybe_listing, check_date=True)) is not None:
            return parsed
        else:
            return result(ListingResult.UNAUTHORISED)
    else:
        return result(ListingResult.NOT_FOUND)


@listing_api.route("/<listing_id>", methods=["PATCH"])
@protected_with_user
def update_listing(user: UserData, listing_id: str):
    """
    Update an existing listing
    """
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

    fields = validate_listing_fields(is_unique=False) | {"id": listing_id}  # type: ignore

    if isinstance(fields, tuple):
        return fields

    if "items" in request.json:
        items = get_items()
    else:
        items = None

    placeholders = ", ".join([f"{column} = :{column}" for column in fields.keys()])

    def update_listing(conn: Connection, cursor: Cursor):
        cursor.execute(f"UPDATE listings SET {placeholders} WHERE id = :id", fields)

        if items is not None:
            cursor.execute("DELETE FROM items WHERE listing = ?", (listing_id,))
            if len(items) > 0:
                insert_items(cursor, listing_id_parsed, items)

        conn.commit()

    if user.is_admin:
        current_app.logger.info(
            f"Admin with ID {user.id} edited listing with ID {listing_id_parsed}"
        )

    globals.db.run(update_listing)

    return {"id": str(listing_id)}


@listing_api.route("/<listing_id>", methods=["DELETE"])
@protected_with_user
def delete_listing(user: UserData, listing_id: str):
    """
    Delete an existing listing
    """
    listing_id_parsed = int(listing_id)

    seller = globals.db.retrieve([Listing.seller], Listing.id, listing_id_parsed)

    if seller is not None and (seller == user.id or user.is_admin):

        def run_delete(conn: Connection, cursor: Cursor):
            cursor.execute("DELETE FROM items WHERE listing = ?", (listing_id_parsed,))
            cursor.execute("DELETE FROM listings WHERE id = ?", (listing_id_parsed,))
            conn.commit()

        globals.db.run(run_delete)

        current_app.logger.info(
            f"Listing with ID {listing_id_parsed} was deleted by user with ID {user.id}."
        )

        return result(ListingResult.SUCCESS)
    else:
        return result(ListingResult.UNAUTHORISED)
