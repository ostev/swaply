from flask import Blueprint, abort, request

API_PREFIX = "/api/v1"

api = Blueprint("api", __name__, url_prefix=API_PREFIX)


@api.before_request
def only_accept_json():
    if not request.is_json:
        abort(400, description="Bad request: expected application/json content type")
