from flask import Flask, render_template
from flask_vite import Vite

app = Flask(__name__, template_folder="templates")
vite = Vite(app)

API_PREFIX = "/api/v1/"


@app.route("/")
def home():
    return render_template("index.jinja")


@app.route(API_PREFIX + "concerts")
def search_events():
    