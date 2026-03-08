from dataclasses import dataclass
from functools import wraps
from sqlite3 import Connection, Cursor
import auth.session
import globals
from auth.user import User
from typing import Self
from email_validator import EmailNotValidError, validate_email
from utils import check_sql_identifier, result
import aenum
from api import API_PREFIX
from flask import Blueprint, current_app, request


@dataclass
class UserData:
    id: int
    email: str
    name: str
    is_admin: bool

    def to_dict(self):
        return {
            "email": self.email,
            "id": str(self.id),
            "name": self.name,
            "is_admin": self.is_admin,
        }

    @classmethod
    def by_id(cls, id: int) -> Self | None:
        user = globals.db.retrieve(
            [User.email, User.name, User.privilege_level], User.id, id
        )

        if user is None:
            return None
        else:
            email, name, privilege_level = user

            return cls(id, email, name, bool(privilege_level))


def protected_with_user(route):
    @wraps(route)
    def protected_route(*args, **kwargs):
        user_id = auth.session.get_user_id()

        if user_id is None:
            return {"error": "invalid_session"}, 403
        else:
            current_user = UserData.by_id(user_id)

            if current_user is None:
                return {"error": "insufficient_privileges"}, 403
            else:
                return route(current_user, *args, **kwargs)

    return protected_route


def authenticated_with_user(route):
    @wraps(route)
    def authenticated_route(*args, **kwargs):
        user_id = auth.session.get_user_id()

        if user_id is not None:
            current_user = UserData.by_id(user_id)

            if current_user is not None:
                return route(current_user, *args, **kwargs)

        route(None, *args, **kwargs)

    return authenticated_route


def admin_only(route):
    @wraps(route)
    def admin_only_route(*args, **kwargs):
        user_id = auth.session.get_user_id()

        if user_id is None:
            return {"error": "invalid_session"}, 403
        else:
            current_user = UserData.by_id(user_id)

            if current_user is None or not current_user.is_admin:
                return {"error": "insufficient_privileges"}, 403
            else:
                return route(current_user, *args, **kwargs)

    return admin_only_route


user_api = Blueprint("user", __name__, url_prefix=API_PREFIX + "/user")


@user_api.route("/current")
def get_current_user():
    user_id = auth.session.get_user_id()

    if user_id is None:
        return {"is_logged_in": False}
    else:
        user = UserData.by_id(user_id)

        if user is None:
            auth.session.logout()
            return {"is_logged_in": False}
        else:
            return {"is_logged_in": True} | user.to_dict()


@user_api.route("/")
@admin_only
def get_all(current_user: UserData):
    page = int(request.args.get("p", 0))
    email = request.args.get("email", None)

    results_per_page = 20

    where_expr = (
        " WHERE INSTR(LOWER(email), LOWER(:email)) > 0" if email is not None else ""
    )
    params = {"limit": results_per_page, "offset": page * results_per_page} | (
        {"email": email} if email is not None else {}
    )

    def retrieve_users_with_count(conn: Connection, cursor: Cursor):
        users = cursor.execute(
            f"SELECT id, email, name, privilege_level FROM users{where_expr} LIMIT :limit OFFSET :offset",
            params,
        ).fetchall()
        count = cursor.execute(
            f"""
                SELECT COUNT(users.id)
                FROM users{where_expr}
                """,
            params,
        ).fetchone()[0]

        return (users, count)

    users, count = globals.db.run(retrieve_users_with_count)

    users = [
        {"is_logged_in": current_user.id == id}
        | UserData(id, email, name, bool(privilege_level)).to_dict()
        for (id, email, name, privilege_level) in users
    ]

    return {"users": users, "number_of_pages": count // results_per_page}


class UserResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    FORBIDDEN = 403
    NOT_FOUND = 404


@user_api.route("/<user_id>")
@protected_with_user
def get_user(current_user: UserData, user_id: str):
    id = int(user_id)

    if current_user.id == id or current_user.is_admin:
        user = UserData.by_id(id)

        if user is None:
            return result(UserResult.NOT_FOUND)

        return {"is_logged_in": current_user.id == user.id} | user.to_dict()
    else:
        return result(UserResult.FORBIDDEN)


@user_api.route("/<user_id>", methods=["DELETE"])
@protected_with_user
def delete_user(current_user: UserData, user_id: str):
    id = int(user_id)

    if current_user.id == id or current_user.is_admin:

        def run_delete_user(conn: Connection, cursor: Cursor):
            cursor.execute("DELETE FROM listings WHERE seller = ?", (id,))
            cursor.execute("DELETE FROM sessions WHERE user_id = ?", (id,))
            cursor.execute("DELETE FROM users WHERE id = ?", (id,))
            conn.commit()

        globals.db.run(run_delete_user)

        current_app.logger.info(
            f"User with ID {id} was deleted by user with ID {current_user.id}."
        )

        return "", 204
    else:
        return result(UserResult.FORBIDDEN)


class UpdateUserError(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    FORBIDDEN = 403
    INVALID_EMAIL = 422
    EMAIL_ALREADY_USED = 422


@user_api.route("/<user_id>", methods=["PATCH"])
@protected_with_user
def update_user(current_user: UserData, user_id: str):
    id = int(user_id)

    if not (current_user.id == id or current_user.is_admin):
        return result(UpdateUserError.FORBIDDEN)

    is_admin = (
        is_admin
        if type(is_admin := request.json.get("is_admin", None)) is bool
        else None
    )

    try:
        email = (
            validate_email(email, check_deliverability=False).normalized
            if type(email := request.json.get("email", None)) is str
            else None
        )
    except EmailNotValidError:
        return result(UpdateUserError.INVALID_EMAIL)

    id_with_email = globals.db.retrieve([User.id], User.email, email)
    if id_with_email is not None and id_with_email != id:
        return result(UpdateUserError.EMAIL_ALREADY_USED)

    params = (
        {"id": id}
        | ({"privilege_level": int(is_admin)} if is_admin is not None else {})
        | ({"email": email} if email is not None else {})
    )

    columns = ", ".join(
        [f"{check_sql_identifier(column)} = :{column}" for column in params.keys()]
    )

    def run_update_user(conn: Connection, cursor: Cursor):
        cursor.execute(f"UPDATE users SET {columns} WHERE id = :id", params)
        conn.commit()

    if current_user.is_admin:
        current_app.logger.info(
            f"Admin with ID {current_user.id} updated the user account with ID {id}."
        )

    globals.db.run(run_update_user)

    return get_user(user_id)  # type: ignore
