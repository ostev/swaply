from datetime import UTC, datetime
from enum import Enum
import json
from sqlite3 import Connection, Cursor
from flask import Blueprint, g, request

from api import API_PREFIX
from auth.session import authenticated, protected
from auth.user import User
from db.schema import Column, PrimaryKey, table
from utils import normalise_json_str_array, result


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

    # Stored as a JSON array of strings
    ticket_types = Column.text()


event_api = Blueprint("events", __name__, url_prefix=API_PREFIX + "/event")


class EventResult(Enum):
    SUCCESS = 200
    NOT_FOUND = 404
    UNAUTHORISED = 401


@event_api.route("/")
@authenticated
def search_events(user_id: int | None):
    search_query = request.args.get("q", None)

    def retrieve_events(conn: Connection, cursor: Cursor):
        if user_id is None:
            if search_query is None:
                return cursor.execute(
                    "SELECT id, name, date, manager FROM events WHERE is_published = 1"
                ).fetchall()
            else:
                return cursor.execute(
                    "SELECT id, name, date, manager FROM events WHERE name LIKE %?% AND is_published = 1",
                    (search_query,),
                ).fetchall()
        else:
            if search_query is None:
                return cursor.execute(
                    "SELECT id, name, date, manager FROM events WHERE is_published = 1 OR manager = ?",
                    (user_id,),
                ).fetchall()
            else:
                return cursor.execute(
                    "SELECT id, name, date, manager FROM events WHERE name LIKE %?% AND (is_published = 1 OR manager = ?)",
                    (search_query, user_id),
                ).fetchall()

    events = g.db.run(retrieve_events)

    return events


@event_api.route("/", methods=["POST"])
@protected
def create_event(user_id: int):
    name = str(request.form["name"])
    date = datetime.fromisoformat(str(request.form["date"])).astimezone(UTC)

    is_published = bool(request.form.get("is_published", False))
    ticket_types = normalise_json_str_array(
        request.form.get("ticket_types", "Standard")
    )

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(
            "INSERT INTO events (name, date, is_published, ticket_types, manager) VALUES (?, ?, ?)",
            (name, date, is_published, ticket_types, user_id),
        )
        conn.commit()

    g.db.run(insert_event)

    return result(EventResult.SUCCESS)


@event_api.route("/events/<event_id>", methods=["GET"])
@authenticated
def get_event(user_id: int | None, event_id: int):
    maybe_event = g.db.retrieve(
        [Event.manager, Event.date, Event.is_published, Event.ticket_types],
        Event.id,
        event_id,
    )

    if maybe_event is not None:
        manager, date, is_published, ticket_types = maybe_event

        if is_published or (int(manager) == user_id and user_id is not None):
            return result(
                EventResult.SUCCESS,
                {
                    "manager": manager,
                    "date": datetime.fromisoformat(date).isoformat(),
                    "is_published": bool(is_published),
                    "ticket_types": map(str, json.loads(ticket_types)),
                },
            )
        else:
            return result(EventResult.UNAUTHORISED)
    else:
        return result(EventResult.NOT_FOUND)


@event_api.route("/<event_id>", methods=["PATCH"])
@protected
def update_event(user_id: int, event_id: int):
    manager_id: int | None = g.db.run(
        lambda conn, cursor: cursor.execute(
            "SELECT manager FROM events WHERE event_id = ?", (event_id,)
        ).fetchone()
    )

    if manager_id == None:
        return result(EventResult.NOT_FOUND)

    if user_id != manager_id:
        return result(EventResult.UNAUTHORISED)

    fields: dict[str, str | int] = {"event_id": event_id}

    if (name := request.form.get("name", None)) is not None:
        fields["name"] = name

    if (form_date := request.form.get("name", None)) is not None:
        fields["date"] = str(datetime.fromisoformat(form_date).astimezone(UTC))

    if (ticket_types := request.form.get("name", None)) is not None:
        fields["ticket_types"] = normalise_json_str_array(ticket_types)

    placeholders = ", ".join([f"{column} = :{column}" for column in fields.keys()])

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(f"UPDATE events SET {placeholders} WHERE id = :event_id", fields)
        conn.commit()

    g.db.run(insert_event)

    return result(EventResult.SUCCESS)
