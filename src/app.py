from sqlite3 import Connection, Cursor
from flask import Flask, render_template, request
from flask_vite import Vite

from db import Database
from db.schema import Column, PrimaryKey, Schema, Table, Type, table

app = Flask(__name__, template_folder="templates")
vite = Vite(app)


@table
class Events(Table):
    table_name = "events"
    id = PrimaryKey(Type.INT).autoincrement()
    name = Column(Type.TEXT)


schema = Schema([Events])

db = Database("db.sqlite3", schema)
db.create()

API_PREFIX = "/api/v1/"


@app.route("/")
def home():
    return render_template("index.jinja")


@app.route(API_PREFIX + "events")
def search_events():
    search_query = request.args.get("q", None)

    def retrieve_events(conn: Connection, cursor: Cursor):
        if search_query is None:
            return cursor.execute("SELECT * FROM events").fetchall()
        else:
            return cursor.execute(
                "SELECT id, name FROM events WHERE name LIKE %?%", (search_query,)
            ).fetchall()

    events = db.run(retrieve_events)

    return events


@app.route(API_PREFIX + "events/create", methods=["POST"])
def create_event():
    name = str(request.form["name"])

    def insert_event(conn: Connection, cursor: Cursor):
        cursor.execute("INSERT INTO events (name) VALUES (?)", (name,))
        conn.commit()

    db.run(insert_event)

    return search_events()
