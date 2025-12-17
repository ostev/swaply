from flask import Blueprint

API_PREFIX = "/api/v1"

api = Blueprint("api", __name__, url_prefix=API_PREFIX)
