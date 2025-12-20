from datetime import datetime, timedelta, UTC
from functools import wraps
import secrets
from sqlite3 import Connection, Cursor
from uuid import uuid7

from flask import session

from auth.hasher import BlakeHasher, SaltedHash
from db.schema import Column, PrimaryKey, table
from auth.user import User
import globals


@table
class Session:
    table_name = "sessions"
    id = PrimaryKey.blob()
    user_id = Column.foreign(User.id)

    expiry_datetime = Column.text()
    hashed_token = Column.blob()
    token_salt = Column.blob()


def register(user_id: int, expiry_days: int = 14):
    expiry_datetime = datetime.now(UTC) + timedelta(expiry_days)

    session_id = uuid7().bytes
    token = secrets.token_bytes(32)
    salted_hash = BlakeHasher().hash(token)

    def insert_session(conn: Connection, cursor: Cursor):
        cursor.execute(
            """
            INSERT INTO sessions (id, user_id, expiry_datetime, hashed_token, token_salt)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                session_id,
                user_id,
                expiry_datetime.isoformat(),
                salted_hash.hash,
                salted_hash.salt,
            ),
        )
        conn.commit()

    globals.db.run(insert_session)

    session["auth_token"] = token
    session["auth_session_id"] = session_id


def get_user_id() -> int | None:
    if "auth_session_id" in session and "auth_token" in session:
        session_id: bytes = session["auth_session_id"]
        token: bytes = session["auth_token"]

        def get_session(
            conn: Connection, cursor: Cursor
        ) -> tuple[int, bytes, bytes, str] | None:
            return cursor.execute(
                "SELECT user_id, hashed_token, token_salt, expiry_datetime FROM sessions WHERE id = ?",
                (session_id,),
            ).fetchone()

        maybe_session = globals.db.run(get_session)

        if maybe_session is not None:
            user_id, hashed_token, token_salt, expiry_datetime = maybe_session

            hash_matches = BlakeHasher().verify(
                token, SaltedHash(hashed_token, token_salt)
            )

            # Check whether the session expiry datetime is still in the future
            has_expired = datetime.fromisoformat(expiry_datetime).astimezone(
                UTC
            ) <= datetime.now(UTC)

            if hash_matches and not has_expired:
                return user_id

    logout()
    return None


def logout():
    session.pop("auth_token", None)
    session_id = session.pop("auth_session_id", None)

    if session_id is not None:

        def delete_session(conn: Connection, cursor: Cursor):
            cursor.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
            conn.commit()

        globals.db.run(delete_session)


def protected(route):
    @wraps(route)
    def protected_route(*args, **kwargs):
        user_id = get_user_id()

        if user_id is None:
            return {"error": "invalid_session"}, 403
        else:
            return route(user_id, *args, **kwargs)

    return protected_route


def authenticated(route):
    @wraps(route)
    def protected_route(*args, **kwargs):
        user_id = get_user_id()

        return route(user_id, *args, **kwargs)

    return protected_route
