from pathlib import Path
import secrets

from flask import Flask, g, render_template, request
from flask_vite import Vite

from db import Database
from model import schema

app = Flask(__name__, template_folder="templates")
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

with app.app_context():
    if "db" not in g:
        g.db = Database("db.sqlite3", schema)
        g.db.create()


@app.teardown_appcontext
def teardown_db(exception):
    db = g.pop("db", None)

    if db is not None:
        db.close()


@app.route("/")
def home():
    return render_template("index.jinja")
