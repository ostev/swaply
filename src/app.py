from pathlib import Path
import secrets
import sqlite3
import tomllib

from flask import Flask, render_template
from flask_vite import Vite
from flask_apscheduler import APScheduler
from flask_talisman import Talisman


from auth import session
import auth.pre_session
import auth.user_api
import auth.session
from db import Database
from model import schema
import listing
import auth
import globals
import model

app = Flask(__name__, template_folder="templates")
with app.app_context():
    if not app.debug:
        app.config["SESSION_COOKIE_SECURE"] = True
        app.config["SESSION_COOKIE_SAMESITE"] = "Strict"
app.register_blueprint(listing.listing_api)
app.register_blueprint(auth.auth_api)
app.register_blueprint(auth.user_api.user_api)


@app.context_processor
def inject_csrf_token():
    def csrf_token():
        auth_csrf = auth.session.authenticated_csrf_token()
        if auth_csrf is None:
            return auth.pre_session.unauthenticated_csrf_token()
        else:
            return auth_csrf

    return {"csrf_token": csrf_token}


if app.debug:
    csp = {
        "default-src": "'self' http://localhost:3000 ws://localhost:3000",
        "object-src": "'none'",
        "style-src": "'self' 'unsafe-inline'",
    }
else:
    csp = {
        "default-src": "'self'",
        "object-src": "'none'",
        "style-src": "'self' 'unsafe-inline'",
    }

Talisman(
    app,
    content_security_policy=csp,
    frame_options="DENY",
)

globals.db = Database("db.sqlite3", model.schema)
globals.db.create()

scheduler = APScheduler()
scheduler.init_app(app)
scheduler.start()


@scheduler.task("interval", id="cleanup_sessions", minutes=20, misfire_grace_time=2000)
def cleanup_expired_sessions():
    with scheduler.app.app_context():  # type: ignore
        app.logger.info("=== Cleaning expired sessions ===")
        auth.session.clear_expired()
        auth.pre_session.clear_expired()
        app.logger.info("=== Finished cleaning expired sessions ===")


def create_search_index(conn: sqlite3.Connection, cursor: sqlite3.Cursor):
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


globals.db.run(create_search_index)
vite = Vite(app)


def set_secrets():
    secret_key_path = Path("../secrets/secret_key")

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
    default_admin_path = Path("../secrets/default_admin.toml")

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


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def client_routed(path):
    return render_template("index.jinja")
