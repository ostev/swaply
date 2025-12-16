from enum import Enum

from sqlite3 import Connection, Cursor
from flask import Blueprint, make_response, request, session
from email_validator import EmailNotValidError, validate_email

from auth.hasher import ArgonHasher
from auth.user import PrivilegeLevel, User
from globals import g

from api import API_PREFIX
import auth.session
from utils import result

auth_api = Blueprint("auth", __name__, url_prefix=API_PREFIX + "/auth")


class LoginResult(Enum):
    SUCCESS = 201
    INCORRECT_CREDENTIALS = 401
    INVALID_EMAIL = 422


@auth_api.route("/login", methods=["POST"])
def login():
    email = request.form["email"]
    password = request.form["password"]

    try:
        normalized_email = validate_email(email, check_deliverability=False).normalized
    except EmailNotValidError:
        return result(LoginResult.INVALID_EMAIL)

    def get_user(conn: Connection, cursor: Cursor) -> tuple[int, str] | None:
        return cursor.execute(
            "SELECT id, hashed_password FROM users WHERE email = ?", normalized_email
        ).fetchone()

    maybe_user = g.db.run(get_user)

    if maybe_user is not None:
        user_id, hashed_password = maybe_user

        if ArgonHasher().verify(password, hashed_password):
            auth.session.register(user_id)

            return result(LoginResult.SUCCESS)

    return result(LoginResult.INCORRECT_CREDENTIALS)


class SignupResult(Enum):
    SUCCESS = 201
    INVALID_PASSWORD = 422
    INVALID_EMAIL = 422


MIN_PASSWORD_LENGTH = 8


@auth_api.route("/signup", methods=["POST"])
def signup():
    email = request.form["email"]
    password = request.form["password"]

    try:
        normalized_email = validate_email(email, check_deliverability=True).normalized
    except EmailNotValidError:
        return result(SignupResult.INVALID_EMAIL)

    if len(password) < MIN_PASSWORD_LENGTH:
        return result(SignupResult.INVALID_PASSWORD)

    if g.db.contains(User.email, normalized_email):
        # Just say that the email is invalid to avoid
        # leaking information about which emails correspond
        # users in a potential enumeration attack.
        return result(SignupResult.INVALID_EMAIL)

    hashed_password = ArgonHasher().hash(password)

    def insert_user(conn: Connection, cursor: Cursor):
        cursor.execute(
            """
            INSERT INTO users (email, hashed_password, privilege_level)
            VALUES (?, ?, ?)
            """,
            (normalized_email, hashed_password, PrivilegeLevel.NORMAL.value),
        )

    g.db.run(insert_user)

    return result(SignupResult.SUCCESS)


@auth_api.route("/login/status")
def login_status():
    return {"is_logged_in": auth.session.get_user_id() is not None}
