from datetime import UTC, datetime
from enum import Enum
import json
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

    def retrieve_events(conn: Connection, cursor: Cursor):
        if user_id is None:
            if search_query is None or len(search_query) == 0:
                return cursor.execute(
                    "SELECT id, name, date, manager, tags FROM events WHERE is_published = 1"
                ).fetchall()
            else:
                return cursor.execute(
                    "SELECT id, name, date, manager, tags FROM events WHERE name MATCH ? AND is_published = 1 ORDER BY bm25(name) DESC",
                    (search_query,),
                ).fetchall()
        else:
            if search_query is None or len(search_query) == 0:
                return cursor.execute(
                    "SELECT id, name, date, manager, tags FROM events WHERE is_published = 1 OR manager = ?",
                    (user_id,),
                ).fetchall()
            else:
                return cursor.execute(
                    "SELECT * FROM event_search_index WHERE name MATCH ?",
                    (search_query,),
                ).fetchall()

    events = globals.db.run(retrieve_events)
    print(events)

    return events


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

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(
            "INSERT INTO events (name, date, is_published, manager, tags) VALUES (?, ?, ?, ?, ?)",
            (name, date, is_published, user_id, tag_string),
        )

        if cursor.lastrowid is None:
            raise ValueError("Failed to create event")

        event_id = int(cursor.lastrowid)
        insert_ticket_types(cursor, event_id, ticket_types)

        conn.commit()

    globals.db.run(insert_event)

    return result(EventResult.SUCCESS)


@event_api.route("/<event_id>", methods=["GET"])
@authenticated
def get_event(user_id: int | None, event_id: int):
    maybe_event = globals.db.retrieve(
        [Event.manager, Event.date, Event.is_published, Event.tags],
        Event.id,
        event_id,
    )

    if maybe_event is not None:
        manager, date, is_published, tag_string = maybe_event

        ticket_types = [
            {"name": str(name), "price": float(price), "allotted": int(allotted)}
            for (name, price, allotted) in globals.db.retrieve_all(
                [TicketType.name, TicketType.price, TicketType.allotted],
                TicketType.id,
                event_id,
            )
        ]

        if is_published or (int(manager) == user_id and user_id is not None):
            return result(
                EventResult.SUCCESS,
                {
                    "manager": manager,
                    "date": datetime.fromisoformat(date).isoformat(),
                    "is_published": bool(is_published),
                    "ticket_types": ticket_types,
                    "tags": [tag.strip() for tag in tag_string.split(",")],
                },
            )
        else:
            return result(EventResult.UNAUTHORISED)
    else:
        return result(EventResult.NOT_FOUND)


@event_api.route("/<event_id>", methods=["PUT"])
@protected
def update_event(user_id: int, event_id_str: str):
    event_id = int(event_id_str)

    manager_id: int | None = globals.db.run(
        lambda conn, cursor: cursor.execute(
            "SELECT manager FROM events WHERE event_id = ?", (event_id,)
        ).fetchone()
    )

    if manager_id == None:
        return result(EventResult.NOT_FOUND)

    if user_id != manager_id:
        return result(EventResult.UNAUTHORISED)

    name = str(request.json["name"])

    if len(name) < 3:
        return result(EventResult.INVALID_NAME)

    fields: dict[str, str | int] = {
        "event_id": event_id,
        "name": name,
        "date": str(datetime.fromisoformat(str(request.json["date"])).astimezone(UTC)),
    }

    if request.json.get("ticket_types", None) is not None:
        ticket_types = get_ticket_types()
    else:
        ticket_types = []

    placeholders = ", ".join([f"{column} = :{column}" for column in fields.keys()])

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(f"UPDATE events SET {placeholders} WHERE id = :event_id", fields)

        cursor.execute("DELETE FROM ticket_types WHERE event = ?", (event_id,))
        if len(ticket_types) > 0:
            insert_ticket_types(cursor, event_id, ticket_types)

        conn.commit()

    globals.db.run(insert_event)

    return result(EventResult.SUCCESS)
