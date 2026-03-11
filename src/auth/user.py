from enum import Enum
from sqlite3 import Connection, Cursor

from auth.hasher import ArgonHasher
from db.schema import Column, PrimaryKey, table

import globals


@table
class User:
    table_name = "users"
    id = PrimaryKey.integer().autoincrement()

    email = Column.text()
    name = Column.text()
    hashed_password = Column.text()

    privilege_level = Column.integer()


class PrivilegeLevel(Enum):
    NORMAL = 0
    ADMIN = 1


def create(email: str, name: str, password: str, is_admin: bool) -> int:
    hashed_password = ArgonHasher().hash(password)

    def insert_user(conn: Connection, cursor: Cursor):
        cursor.execute(
            """
            INSERT INTO users (email, name, hashed_password, privilege_level)
            VALUES (?, ?, ?, ?)
            RETURNING id
            """,
            (email, name, hashed_password, int(is_admin)),
        )

        user_id_tuple = cursor.fetchone()

        if user_id_tuple is None:
            raise ValueError("Failed to create user")
        user_id = user_id_tuple[0]

        conn.commit()
        return user_id

    return globals.db.run(insert_user)
