import sqlite3
from typing import Any, Callable

from db import schema
from db.schema import Schema
from threading import Lock

from utils import check_sql_identifier


class LockedConnection:
    def __init__(self, path: str):
        self.db_conn = sqlite3.connect(path, check_same_thread=False)

        self.lock = Lock()

        # Enable checking foreign key constraints
        self.db_conn.execute("PRAGMA foreign_keys = 1")


class Database:
    def __init__(self, path: str, schema: Schema, number_of_connections=8) -> None:
        self._schema = schema

        self._connections = [
            LockedConnection(path) for _ in range(number_of_connections)
        ]

    # def retrieve_all(self, column, value) -> list[Any]:
    #     column_name = check_sql_identifier(column.name)
    #     table_name = check_sql_identifier(column.table.table_name)

    #     return self.run(
    #         lambda conn, cursor: cursor.execute(
    #             f"SELECT * FROM {table_name} WHERE {column_name} = ?", value
    #         ).fetchall()
    #     )
    def retrieve_all(self, select_columns, where_column, value) -> list[Any]:
        column_name = check_sql_identifier(where_column.name)
        table_name = check_sql_identifier(where_column.table.table_name)

        select_columns_list = ", ".join(
            [check_sql_identifier(column.name) for column in select_columns]
        )

        return self.run(
            lambda conn, cursor: cursor.execute(
                f"SELECT {select_columns_list} FROM {table_name} WHERE {column_name} = ?",
                (value,),
            ).fetchall()
        )

    def retrieve(self, select_columns, where_column, value) -> Any | None:
        column_name = check_sql_identifier(where_column.name)
        table_name = check_sql_identifier(where_column.table.table_name)

        select_columns_list = ", ".join(
            [check_sql_identifier(column.name) for column in select_columns]
        )

        return self.run(
            lambda conn, cursor: cursor.execute(
                f"SELECT {select_columns_list} FROM {table_name} WHERE {column_name} = ?",
                (value,),
            ).fetchone()
        )

    def contains(self, column, value) -> bool:
        column_name = check_sql_identifier(column.name)
        table_name = check_sql_identifier(column.table.table_name)

        def does_table_contain(
            conn: sqlite3.Connection, cursor: sqlite3.Cursor
        ) -> bool:
            return (
                cursor.execute(
                    f"SELECT {column_name} FROM {table_name} WHERE {column_name} = ?",
                    (value,),
                ).fetchone()
                is not None
            )

        return self.run(does_table_contain)

    def close(self):
        for conn in self._connections:
            with conn.lock:
                conn.db_conn.close()

    def create(self):
        def create_db(conn: sqlite3.Connection, cursor: sqlite3.Cursor):
            print(self._schema.to_create_query())
            cursor.executescript(self._schema.to_create_query())
            conn.commit()

        self.run(create_db)

    def run[T](self, operation: Callable[[sqlite3.Connection, sqlite3.Cursor], T]) -> T:
        for conn in self._connections:
            if not conn.lock.locked():
                with conn.lock:
                    return operation(conn.db_conn, conn.db_conn.cursor())

        conn = self._connections[0]
        with conn.lock:
            return operation(conn.db_conn, conn.db_conn.cursor())
