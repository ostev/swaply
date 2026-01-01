from dataclasses import dataclass
from functools import wraps
from sqlite3 import Connection, Cursor
import auth.session
import globals
from auth.user import User
from typing import Self
from utils import result
import aenum
from api import API_PREFIX
from flask import Blueprint, request


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


def admin_only(route):
    @wraps(route)
    def admin_only_route(*args, **kwargs):
        user_id = auth.session.get_user_id()

        if user_id is None:
            return {"error": "invalid_session"}, 403
        else:
            current_user = UserData.by_id(user_id)

            if current_user is None:
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
    page = request.args.get("p", 0)
    email = request.args.get("email", None)

    results_per_page = 20

    where_expr = " WHERE email LIKE %:email%" if email is not None else ""
    params = {"limit": results_per_page, "offset": page * results_per_page} | (
        {"email": email} if email is not None else {}
    )

    users = [
        {"is_logged_in": current_user.id == id}
        | UserData(id, email, name, bool(privilege_level)).to_dict()
        for (id, email, name, privilege_level) in globals.db.run(
            lambda conn, cursor: cursor.execute(
                f"SELECT id, email, name, privilege_level FROM users{where_expr} LIMIT :limit OFFSET :offset",
                params,
            ).fetchall()
        )
    ]

    return {}


class EventResult(aenum.Enum):  # type: ignore
    _settings_ = aenum.NoAlias

    NOT_FOUND = 404


@user_api.route("/<user_id>")
@admin_only
def get_user(_: UserData, user_id: str):
    id = int(user_id)

    user = UserData.by_id(id)

    if user is None:
        return result(EventResult.NOT_FOUND)

    return user.to_dict()


@user_api.route("/<user_id>", methods=["DELETE"])
@admin_only
def delete_user(_: UserData, user_id: str):
    id = int(user_id)

    def run_delete_user(conn: Connection, cursor: Cursor):
        cursor.execute("DELETE FROM users WHERE id = ?", (id,))
        conn.commit()

    globals.db.run(run_delete_user)

    return "", 204
