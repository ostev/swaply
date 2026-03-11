import json
import pathlib
import re
import secrets
from typing import Any

from flask import abort, make_response, jsonify


def result(result, json_response: dict[str, Any] = {}) -> tuple[dict[str, Any], int]:
    message = result.name.lower()
    status_code = int(result.value)

    return {"result": message} | json_response, status_code


def error(result):
    abort(make_response(jsonify({"result": result.name.lower()}), int(result.value)))


def normalise_json_str_array(input: str) -> str:
    return json.dumps(map(str, json.loads(input)))


def check_sql_identifier(name: str) -> str:
    if len(re.findall(r"^([a-zA-Z]|_)([a-zA-z]|\d|_)*$", name)) > 0:
        return name
    else:
        raise ValueError(f"Illegal SQL identifier: {name}")


def load_newline_seperated_values(path) -> set[str]:
    with open(path) as file:
        return set(map(lambda line: line.strip().lower(), file.readlines()))


def load_data(filename) -> set[str]:
    return load_newline_seperated_values(
        pathlib.Path(__file__).parent.resolve() / "data" / filename
    )


def get_secret(path: pathlib.Path, num_bytes: int = 16) -> str:
    """
    Retrieves a secret key from a file or generates it if it doesn't exist.
    """
    try:
        with open(path, "r") as file:
            return file.read()
    except FileNotFoundError:
        path.parent.mkdir(parents=True, exist_ok=True)

        with open(path, "w") as file:
            secret_key = secrets.token_hex(num_bytes)
            file.write(secret_key)

            return secret_key
