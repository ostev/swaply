from pathlib import Path
import secrets
import sqlite3
import tomllib

from flask import Flask, g, render_template, request
from flask_vite import Vite

import auth.user_api
from db import Database
from model import schema
import event
import auth
import globals
import model

app = Flask(__name__, template_folder="templates")
app.register_blueprint(event.event_api)
app.register_blueprint(auth.auth_api)
app.register_blueprint(auth.user_api.user_api)
# with app.app_context():
# if "db" not in g:
#     g.db = Database("db.sqlite3", schema)
#     g.db.create()
globals.db = Database("db.sqlite3", model.schema)
globals.db.create()


def create_search_index(conn: sqlite3.Connection, cursor: sqlite3.Cursor):
    cursor.executescript(
        """
        CREATE VIRTUAL TABLE IF NOT EXISTS event_search_index
            USING fts5(
                name,
                tags,
                description,
                short_description,
                location,
                content="events",
                content_rowid="id",
                tokenize="trigram"
            );

        CREATE TRIGGER IF NOT EXISTS event_insert_trigger AFTER INSERT ON events BEGIN
            INSERT INTO
                event_search_index(
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

        CREATE TRIGGER IF NOT EXISTS event_delete_trigger AFTER DELETE ON events BEGIN
            INSERT INTO
                event_search_index(
                    event_search_index,
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

        CREATE TRIGGER IF NOT EXISTS event_update_trigger AFTER UPDATE ON events BEGIN
            INSERT INTO
                event_search_index(
                    event_search_index,
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
                event_search_index(
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


globals.db.run(create_search_index)
vite = Vite(app)


def set_secrets():
    secret_key_path = Path("secrets/secret_key")

    try:
        with open(secret_key_path, "r") as file:
            app.secret_key = file.read()
    except FileNotFoundError:
        secret_key_path.parent.mkdir(parents=True, exist_ok=True)

        with open(secret_key_path, "w") as file:
            secret_key = secrets.token_hex(32)
            file.write(secret_key)

            app.secret_key = secret_key


set_secrets()


def create_default_admin():
    default_admin_path = Path("secrets/default_admin.toml")

    with open(default_admin_path, "rb") as file:
        admin_details = tomllib.load(file)

        email = str(admin_details["email"])
        name = str(admin_details["name"])
        password = str(admin_details["password"])

    if (
        globals.db.run(
            lambda conn, cursor: cursor.execute(
                "SELECT COUNT(id) FROM users WHERE privilege_level = 1"
            ).fetchone()
        )[0]
        == 0
    ):
        auth.create_user(email, name, password, is_admin=True)


create_default_admin()


@app.teardown_appcontext
def teardown_db(exception):
    db = g.pop("db", None)

    if db is not None:
        db.close()


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def client_routed(path):
    return render_template("index.jinja")
