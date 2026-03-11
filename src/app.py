from pathlib import Path
import secrets
import sqlite3
import tomllib

from flask import Flask, abort, render_template, request
from flask_vite import Vite
from flask_apscheduler import APScheduler
from flask_talisman import Talisman
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address


from auth import session
import auth.admin
import auth.user_api
import auth.user
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

limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["240 per minute"],
    storage_uri="memory://",
)

secrets_dir = Path(__file__).parent.parent.resolve() / "secrets"
# Secret key used to sign cookies etc.
app.secret_key = get_secret(secrets_dir / "secret_key", num_bytes=32)
# This isn't actually secret, but just needs to be a static value that we can check.
csrf_header_value = get_secret(secrets_dir / "csrf_header_value", num_bytes=16)


@app.context_processor
def inject_csrf_token():
    """
    Adds a variable to Jinja templates with the static CSRF header value
    """
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


csp = {
    "default-src": "'self'",
    "object-src": "'none'",
    "style-src": "'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src": "'self' https://fonts.gstatic.com",
}

if not app.debug:
    # Only enforce CSP if in production. In development, it can cause issues with dev server,
    # proxies, etc.
    Talisman(
        app,
        content_security_policy=csp,
        frame_options="DENY",
    )

globals.db = Database(
    Path(__file__).parent.parent.resolve() / "db" / "db.sqlite3", model.schema
)
globals.db.create()
globals.db.run(listing.create_search_index)
auth.admin.create_default(secrets_dir)

scheduler = APScheduler()
scheduler.init_app(app)
scheduler.start()


@scheduler.task("interval", id="cleanup_sessions", minutes=20, misfire_grace_time=2000)
def cleanup_expired_sessions():
    """
    Runs periodically to clean the database of expired authentication sessions
    """
    with scheduler.app.app_context():  # type: ignore
        app.logger.info("=== Cleaning expired sessions ===")
        auth.session.clear_expired()
        app.logger.info("=== Finished cleaning expired sessions ===")


app.config["VITE_FOLDER_PATH"] = Path(__file__).parent.parent.resolve() / "vite"
vite = Vite(app)


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def client_routed(path):
    # Non-API routing is handled on the client side, so we just render
    # a single template that loads our frontend code.
    return render_template("index.jinja")
