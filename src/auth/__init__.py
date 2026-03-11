import aenum

from sqlite3 import Connection, Cursor
from flask import Blueprint, current_app, request
from email_validator import EmailNotValidError, validate_email

from auth.hasher import ArgonHasher
import auth.user
from auth.user import User
import auth.session

from api import API_PREFIX
from utils import load_data, result
import globals

auth_api = Blueprint("auth", __name__, url_prefix=API_PREFIX + "/auth")

words = load_data("words.txt")
common_passwords = load_data("Pwdb_top-1000.txt")


class LoginResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    SUCCESS = 201
    INCORRECT_CREDENTIALS = 401
    INVALID_EMAIL = 422


@auth_api.route("/login", methods=["POST"])
def login():
    """
    Creates a new session for an existing user
    """
    email = request.json["email"]
    password = request.json["password"]

    try:
        normalized_email = validate_email(email, check_deliverability=False).normalized
    except EmailNotValidError:
        return result(LoginResult.INVALID_EMAIL)

    def get_user(conn: Connection, cursor: Cursor) -> tuple[int, str] | None:
        return cursor.execute(
            "SELECT id, hashed_password FROM users WHERE email = ?",
            (normalized_email,),
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
    INVALID_NAME = 422
    EMAIL_ALREADY_USED = 422
    PASSWORD_IS_COMMON = 422
    PASSWORD_CONTAINS_EMAIL = 422
    PASSWORD_IS_WORD = 422


MIN_PASSWORD_LENGTH = 8


@auth_api.route("/signup", methods=["POST"])
def signup():
    """
    Creates an account and a session for a new user
    """
    email = str(request.json["email"])
    name = str(request.json["name"])
    password = str(request.json["password"])

    try:
        normalized_email = validate_email(
            email, check_deliverability=not current_app.debug
        ).normalized
    except EmailNotValidError:
        return result(SignupResult.INVALID_EMAIL)

    if len(password) < MIN_PASSWORD_LENGTH:
        return result(SignupResult.INVALID_PASSWORD)

    if len(name.strip()) < 2:
        return result(SignupResult.INVALID_NAME)

    lowercase_password = password.lower()
    if lowercase_password in words:
        return result(SignupResult.PASSWORD_IS_WORD)
    if lowercase_password in common_passwords:
        return result(SignupResult.PASSWORD_IS_COMMON)

    if globals.db.contains(User.email, normalized_email):
        return result(SignupResult.EMAIL_ALREADY_USED)

    user_id = auth.user.create(normalized_email, name, password, is_admin=False)

    auth.session.register(user_id)

    return result(SignupResult.SUCCESS)


@auth_api.route("/login/status")
def login_status():
    return {"is_logged_in": auth.session.get_user_id() is not None}
