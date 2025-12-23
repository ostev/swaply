import aenum

from sqlite3 import Connection, Cursor
import sys
from flask import Blueprint, make_response, request, session
from email_validator import EmailNotValidError, validate_email

from auth.hasher import ArgonHasher
from auth.user import PrivilegeLevel, User
import auth.session

from api import API_PREFIX
from utils import result
import globals

auth_api = Blueprint("auth", __name__, url_prefix=API_PREFIX + "/auth")


class LoginResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    SUCCESS = 201
    INCORRECT_CREDENTIALS = 401
    INVALID_EMAIL = 422


@auth_api.route("/login", methods=["POST"])
def login():
    email = request.json["email"]
    password = request.json["password"]

    try:
        normalized_email = validate_email(email, check_deliverability=False).normalized
    except EmailNotValidError:
        return result(LoginResult.INVALID_EMAIL)

    def get_user(conn: Connection, cursor: Cursor) -> tuple[int, str] | None:
        return cursor.execute(
            "SELECT id, hashed_password FROM users WHERE email = ?", (normalized_email,)
        ).fetchone()

    maybe_user = globals.db.run(get_user)

    if maybe_user is not None:
        user_id, hashed_password = maybe_user

        if ArgonHasher().verify(password, hashed_password):
            auth.session.register(user_id)

            return result(LoginResult.SUCCESS)

    return result(LoginResult.INCORRECT_CREDENTIALS)


@auth_api.route("/logout", methods=["POST"])
def logout():
    auth.session.logout()

    return "", 204


class SignupResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    SUCCESS = 201
    INVALID_PASSWORD = 422
    INVALID_EMAIL = 422
    EMAIL_ALREADY_USED = 422


MIN_PASSWORD_LENGTH = 8


@auth_api.route("/signup", methods=["POST"])
def signup():
    email = request.json["email"]
    name = request.json["name"]
    password = request.json["password"]

    try:
        normalized_email = validate_email(email, check_deliverability=True).normalized
    except EmailNotValidError:
        return result(SignupResult.INVALID_EMAIL)

    if len(password) < MIN_PASSWORD_LENGTH:
        return result(SignupResult.INVALID_PASSWORD)

    if globals.db.contains(User.email, normalized_email):
        return result(SignupResult.EMAIL_ALREADY_USED)

    hashed_password = ArgonHasher().hash(password)

    def insert_user(conn: Connection, cursor: Cursor):
        cursor.execute(
            """
            INSERT INTO users (email, name, hashed_password, privilege_level)
            VALUES (?, ?, ?, ?)
            RETURNING id
            """,
            (normalized_email, name, hashed_password, PrivilegeLevel.NORMAL.value),
        )

        user_id = cursor.fetchone()

        if user_id is None:
            raise ValueError("Failed to create user")

        conn.commit()
        return user_id

    user_id = globals.db.run(insert_user)

    auth.session.register(user_id)

    return result(SignupResult.SUCCESS)


@auth_api.route("/login/status")
def login_status():
    return {"is_logged_in": auth.session.get_user_id() is not None}


@auth_api.route("/user")
def get_current_user():
    user_id = auth.session.get_user_id()

    if user_id is None:
        return {"is_logged_in": False}
    else:
        user = globals.db.retrieve([User.id, User.email, User.name], User.id, user_id)

        if user is None:
            auth.session.logout()
            return {"is_logged_in": False}
        else:
            id, email, name = user

            return {"is_logged_in": True, "email": email, "name": name, "id": str(id)}
