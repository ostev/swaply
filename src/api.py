from datetime import UTC, datetime
from sqlite3 import Connection, Cursor
from flask import Blueprint, request
from auth.session import protected
from globals import g
import json

API_PREFIX = "/api/v1"

api = Blueprint("api", __name__, url_prefix=API_PREFIX)


@api.route("/events")
def search_events():
    search_query = request.args.get("q", None)

    def retrieve_events(conn: Connection, cursor: Cursor):
        if search_query is None:
            return cursor.execute("SELECT * FROM events").fetchall()
        else:
            return cursor.execute(
                "SELECT id, name FROM events WHERE name LIKE %?%", (search_query,)
            ).fetchall()

    events = g.db.run(retrieve_events)

    return events


@api.route("/events/create", methods=["POST"])
@protected
def create_event(user_id: int):
    name = str(request.form["name"])
    date = datetime.fromisoformat(str(request.form["date"])).astimezone(UTC)

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute("INSERT INTO events (name) VALUES (?)", (name,))
        conn.commit()

    g.db.run(insert_event)

    return search_events()


@api.route("/events/update", methods=["POST", "PATCH"])
@protected
def update_event(user_id: int):
    fields = {}

    if (name := request.form.get("name", None)) is not None:
        fields["name"] = name

    if (form_date := request.form.get("name", None)) is not None:
        fields["date"] = str(datetime.fromisoformat(form_date).astimezone(UTC))

    if (ticket_types := request.form.get("name", None)) is not None:
        fields["ticket_types"] = json.dumps(map(str, json.loads(ticket_types)))

    columns = ", ".join(fields.keys())
    value_placeholders = "?, " * (len(fields) - 1) + "?"

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute(
            f"UPDATE events SET ({value_placeholders})",
            tuple(fields.values()),
        )
        conn.commit()

    g.db.run(insert_event)

    return search_events()
