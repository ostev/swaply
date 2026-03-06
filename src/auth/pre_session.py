from datetime import datetime, timedelta
from functools import wraps
import secrets
from sqlite3 import Connection, Cursor
from typing import Optional
import typing

from flask import request, session

from db.schema import Column, PrimaryKey, table

import globals


@table
class PreSession:
    table_name = "pre_sessions"
    id = PrimaryKey.blob()
    csrf_token = Column.blob()
    expiry = Column.text()


LIFETIME = timedelta(minutes=30)


def unauthenticated_csrf_token() -> str:
    return get_or_create_csrf_token().hex()


def create_csrf_token() -> bytes:
    id = secrets.token_bytes(16)
    csrf_token = secrets.token_bytes(16)
    expiry = datetime.now() + LIFETIME

    def insert_session(conn: Connection, cursor: Cursor):
        cursor.execute(
            """
            INSERT INTO pre_sessions (id, csrf_token, expiry)
            VALUES (?, ?, ?)
            """,
            (id, csrf_token, expiry.isoformat()),
        )
        conn.commit()

    globals.db.run(insert_session)

    session["pre_session_id"] = id
    return csrf_token


def get_or_create_csrf_token() -> bytes:
    if (token := get_csrf_token()) is not None:
        return typing.cast(bytes, token)
    else:
        return create_csrf_token()


def get_csrf_token() -> Optional[bytes]:
    if "pre_session_id" in session:
        id = bytes(session["pre_session_id"])
        csrf_token = globals.db.retrieve(
            [
                PreSession.csrf_token,
            ],
            PreSession.id,
            id,
        )

        return csrf_token
    else:
        return None


def verify_csrf_header() -> bool:
    csrf_token = get_csrf_token()
    return (
        csrf_token is not None
        and request.headers.get("X-CSRF-Token") == csrf_token.hex()
    )


def delete():
    id = session.pop("pre_session_id", None)

    if id is not None:

        def delete_session(conn: Connection, cursor: Cursor):
            cursor.execute("DELETE FROM pre_sessions WHERE id = ?", (id,))
            conn.commit()

        globals.db.run(delete_session)


def clear_expired():
    def delete_sessions(conn: Connection, cursor: Cursor):
        cursor.execute("DELETE FROM pre_sessions WHERE expiry < datetime('now')")
        conn.commit()

    globals.db.run(delete_sessions)


def unauthenticated_csrf_protected(route):
    @wraps(route)
    def protected_route(*args, **kwargs):
        if verify_csrf_header():
            return route(*args, **kwargs)
        else:
            return {"error": "invalid_csrf_token"}, 403

    return protected_route
