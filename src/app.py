from pathlib import Path
import secrets
import sqlite3
import tomllib

from flask import Flask, abort, render_template, request
from flask_vite import Vite
from flask_apscheduler import APScheduler
from flask_talisman import Talisman


from auth import session
import auth.user_api
import auth.session
from db import Database
from model import schema
import listing
import auth
import globals
import model
from utils import get_secret

app = Flask(__name__, template_folder="templates")
with app.app_context():
    if not app.debug:
        app.config["SESSION_COOKIE_SECURE"] = True
        app.config["SESSION_COOKIE_SAMESITE"] = "Strict"
app.register_blueprint(listing.listing_api)
app.register_blueprint(auth.auth_api)
app.register_blueprint(auth.user_api.user_api)

secrets_dir = Path(__file__).parent.parent.resolve() / "secrets"
# Secret key used to sign cookies etc.
app.secret_key = get_secret(secrets_dir / "secret_key", num_bytes=32)
# This isn't actually secret, but just needs to be a static value that we can check.
csrf_header_value = get_secret(secrets_dir / "csrf_header_value", num_bytes=16)


@app.context_processor
def inject_csrf_token():
    return {"csrf_header_value": csrf_header_value}


@app.before_request
def disallow_csrf():
    """
    We implement CSRF protection by only allowing complex requests to state-changing URLs.
    This avoids the browser's legacy, insecure behaviour of allowing pages to make cross-site
    simple requests (i.e. form data), meaning that we don't need dynamic CSRF tokens. Since we
    require a custom header and the application/json content type on state-changing requests,
    any state-changing request is inherently complex.
    """

    if request.method not in ("GET", "HEAD", "CONNECT", "OPTIONS", "TRACE"):
        # The request is state-changing
        if request.content_type != "application/json":
            abort(
                400, description="Bad request: expected application/json content type"
            )

        if request.headers.get("X-CSRF-Token") != csrf_header_value:
            abort(400, description="Bad request: expected presence of CSRF header")


if app.debug:
    csp = {
        "default-src": "'self' http://localhost:3000 ws://localhost:3000",
        "object-src": "'none'",
        "style-src": "'self' 'unsafe-inline'",
        "worker-src": "'self' blob:",
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

globals.db = Database(
    Path(__file__).parent.parent.resolve() / "db" / "db.sqlite3", model.schema
)
globals.db.create()

scheduler = APScheduler()
scheduler.init_app(app)
scheduler.start()


@scheduler.task("interval", id="cleanup_sessions", minutes=20, misfire_grace_time=2000)
def cleanup_expired_sessions():
    with scheduler.app.app_context():  # type: ignore
        app.logger.info("=== Cleaning expired sessions ===")
        auth.session.clear_expired()
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


def create_default_admin():
    default_admin_path = secrets_dir / "admin.toml"

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
