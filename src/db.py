import sqlite3

from db.schema import Schema
from db.query import Query
from threading import Lock


class Connection:
    def __init__(self, path: str):
        self._conn = sqlite3.connect(path)
        self._lock = Lock()


class Database:
    def __init__(self, path: str, schema: Schema, number_of_connections=8) -> None:
        self.__schema = schema

        self.__connections = [Connection(path) for _ in range(number_of_connections)]

    # def execute(self, query: Query):
    #     self.__cursor.execute(query)
    #     self.__con.commit()


class Transaction:
    def __init__(self, db: Database) -> None:
        self.__queries = []

    def query(self, query: Query) -> Transaction:
        self.__queries.append(query)
        return self
