import sqlite3
from typing import Callable

from db import schema
from db.schema import Schema
from threading import Lock


class LockedConnection:
    def __init__(self, path: str):
        self.db_conn = sqlite3.connect(path)
        self.lock = Lock()


class Database:
    def __init__(self, path: str, schema: Schema, number_of_connections=8) -> None:
        self._schema = schema

        self._connections = [
            LockedConnection(path) for _ in range(number_of_connections)
        ]

    def run[T](self, operation: Callable[[sqlite3.Connection], T]) -> T:
        for conn in self._connections:
            if not conn.lock.locked():
                with conn.lock:
                    return operation(conn.db_conn)

        conn = self._connections[0]
        with conn.lock:
            return operation(conn.db_conn)
