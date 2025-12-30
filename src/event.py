from datetime import UTC, datetime
from enum import Enum
from functools import reduce
import json
from multiprocessing import Value
from sqlite3 import Connection, Cursor
import aenum
from flask import Blueprint, request

from api import API_PREFIX
from auth.session import authenticated, protected
from auth.user import User
from db.schema import Column, PrimaryKey, table
from utils import normalise_json_str_array, result
import globals


@table
class Event:
    table_name = "events"
    id = PrimaryKey.integer().autoincrement()
    manager = Column.foreign(User.id)

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
    table_name = "ticket_types"
    id = PrimaryKey.integer().autoincrement()
    event = Column.foreign(Event.id)

    name = Column.text()
    price = Column.numeric()
    allotted = Column.integer()


event_api = Blueprint("events", __name__, url_prefix=API_PREFIX + "/events")


class EventResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    SUCCESS = 200
    NOT_FOUND = 404
    UNAUTHORISED = 401
    INVALID_NAME = 400
    NAME_ALREADY_USED = 400


@event_api.route("/search")
@authenticated
def search_events(user_id: int | None):
    search_query = request.args.get("q", None)
    page = request.args.get("p", 0)
    filter_owned = request.args.get("filter_owned", "false").lower() == "true"

    results_per_page = 10

    is_authorized_expr = (
        "(e.is_published = 1 OR manager = :user_id)"
        if user_id is not None
        else "e.is_published = 1"
    )

    filter_expr = (
        "manager = :user_id AND" if (user_id is not None) and filter_owned else ""
    )

    search_query_expr = (
        f"event_search_index MATCH :query AND"
        if search_query is None or len(search_query) >= 3
        else ""
    )

    def retrieve_events_with_ticket_types(conn: Connection, cursor: Cursor):
        return cursor.execute(
            # SELECT e.id, e.name, e.manager, e.date, e.is_published, e.tags
            f"""
            SELECT
                e.id,
                e.name,
                e.manager,
                e.date,
                e.is_published,
                e.tags,
                e.short_description,
                e.description,
                e.location,
                t.name,
                t.price,
                t.allotted
            FROM events AS e
            JOIN event_search_index
                ON event_search_index.ROWID = e.id
            LEFT JOIN ticket_types as t
                ON t.event = e.id
            WHERE {search_query_expr} {filter_expr} {is_authorized_expr}
            LIMIT :results_per_page OFFSET :offset
            """,
            {
                "query": search_query,
                "results_per_page": results_per_page,
                "offset": page * results_per_page,
            }
            | ({"user_id": user_id} if user_id is not None else {}),
        ).fetchall()

    events_with_ticket_types = globals.db.run(retrieve_events_with_ticket_types)

    events = []

    for event_with_ticket_type in events_with_ticket_types:
        (
            id,
            name,
            manager,
            date,
            is_published,
            tags,
            short_description,
            description,
            location,
            ticket_name,
            ticket_price,
            ticket_allotted,
        ) = event_with_ticket_type

        last_index = len(events) - 1

        if ticket_name is not None:
            ticket = {
                "name": str(ticket_name),
                "price": float(ticket_price),
                "allotted": int(ticket_allotted),
            }
        else:
            ticket = None

        if len(events) == 0 or str(id) != events[last_index]["id"]:
            events.append(
                {
                    "id": str(id),
                    "name": str(name),
                    "manager": str(manager),
                    "date": datetime.fromisoformat(date).isoformat(),
                    "is_published": bool(is_published),
                    "tags": tags_from_csv(tags),
                    "ticket_types": [] if ticket is None else [ticket],
                    "short_description": str(short_description),
                    "description": str(description),
                    "location": str(location),
                }
            )
        else:
            events[last_index]["ticket_types"].append(ticket)

    return events


def tags_from_csv(tag_string: str) -> list[str]:
    return [
        stripped_tag
        for tag in str(tag_string).split(",")
        if (stripped_tag := tag.strip())
    ]


def get_ticket_types() -> list[tuple[str, float, int]]:
    return [
        (
            str(ticket_type["name"]),
            float(ticket_type["price"]),
            int(ticket_type["allotted"]),
        )
        for ticket_type in request.json.get("ticket_types", [])
    ]


def insert_ticket_types(
    cursor: Cursor, event_id: int, ticket_types: list[tuple[str, float, int]]
):
    cursor.executemany(
        "INSERT INTO ticket_types (event, name, price, allotted) VALUES (?, ?, ?, ?)",
        [(event_id,) + ticket_type for ticket_type in ticket_types],
    )


@event_api.route("/", methods=["POST"])
@protected
def create_event(user_id: int):
    name = str(request.json["name"])
    if len(name) < 3:
        return result(EventResult.INVALID_NAME)

    if globals.db.run(
        lambda _, cursor: cursor.execute(
            "SELECT id FROM events WHERE name LIKE ?", (name,)
        ).fetchone()
        is not None
    ):
        return result(EventResult.NAME_ALREADY_USED)

    date = datetime.fromisoformat(str(request.json["date"])).astimezone(UTC)

    is_published = bool(request.json.get("is_published", False))
    ticket_types = get_ticket_types()

    tags = [str(tag) for tag in request.json.get("tags", [])]
    tag_string = ",".join(tags)

    short_description = request.json["short_description"]
    description = request.json["description"]

    location = request.json["location"]

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(
            "INSERT INTO events (name, date, is_published, manager, tags, short_description, description, location) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
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
            raise ValueError("Failed to create event")

        event_id = int(cursor.lastrowid)
        insert_ticket_types(cursor, event_id, ticket_types)

        conn.commit()

        return event_id

    event_id = globals.db.run(insert_event)

    return get_event(event_id)  # type: ignore


@event_api.route("/<event_id>", methods=["GET"])
@authenticated
def get_event(user_id: int | None, event_id: int):
    maybe_event = globals.db.retrieve(
        [
            Event.name,
            Event.manager,
            Event.date,
            Event.is_published,
            Event.tags,
            Event.short_description,
            Event.description,
            Event.location,
        ],
        Event.id,
        event_id,
    )

    if maybe_event is not None:
        (
            name,
            manager,
            date,
            is_published,
            tag_string,
            short_description,
            description,
            location,
        ) = maybe_event

        ticket_types = [
            {"name": str(name), "price": float(price), "allotted": int(allotted)}
            for (name, price, allotted) in globals.db.retrieve_all(
                [TicketType.name, TicketType.price, TicketType.allotted],
                TicketType.event,
                event_id,
            )
        ]

        if is_published or (int(manager) == user_id and user_id is not None):
            return {
                "id": str(event_id),
                "name": str(name),
                "manager": str(manager),
                "date": datetime.fromisoformat(date).isoformat(),
                "is_published": bool(is_published),
                "tags": tags_from_csv(tag_string),
                "short_description": str(short_description),
                "description": str(description),
                "location": str(location),
                "ticket_types": ticket_types,
            }
        else:
            return result(EventResult.UNAUTHORISED)
    else:
        return result(EventResult.NOT_FOUND)


@event_api.route("/<event_id>", methods=["PATCH"])
@protected
def update_event(user_id: int, event_id: str):
    event_id_parsed = int(event_id)

    manager_id: int | None = globals.db.run(
        lambda conn, cursor: cursor.execute(
            "SELECT manager FROM events WHERE id = ?", (event_id_parsed,)
        ).fetchone()
    )[0]

    if manager_id == None:
        return result(EventResult.NOT_FOUND)

    if user_id != manager_id:
        return result(EventResult.UNAUTHORISED)

    if "name" in request.json:
        name = str(request.json["name"])

        if len(name) < 3:
            return result(EventResult.INVALID_NAME)
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
            "id": event_id_parsed,
        }
        | ({"name": name} if name is not None else {})
        | ({"date": date} if date is not None else {})
        | ({"is_published": is_published} if is_published is not None else {})
    )

    if "ticket_types" in request.json:
        ticket_types = get_ticket_types()
    else:
        ticket_types = None

    placeholders = ", ".join([f"{column} = :{column}" for column in fields.keys()])

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(f"UPDATE events SET {placeholders} WHERE id = :id", fields)

        if ticket_types is not None:
            cursor.execute("DELETE FROM ticket_types WHERE event = ?", (event_id,))
            if len(ticket_types) > 0:
                insert_ticket_types(cursor, event_id_parsed, ticket_types)

        conn.commit()

    globals.db.run(insert_event)

    return get_event(event_id_parsed)  # type: ignore
