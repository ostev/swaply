from enum import Enum
from typing import TypeVar, cast


class Type(Enum):
    INT = "INTEGER"
    TEXT = "TEXT"


class Column:
    def __init__(self, type: Type):
        self.type = type
        self.is_autoincrement = False
        self.is_nullable = False

    def autoincrement(self):
        self.is_autoincrement = True

    def nullable(self):
        self.is_nullable = True


class NamedColumn:
    def __init__(self, name: str, column: Column):
        self.name = name
        self.column = column

    def to_sql_schema(self) -> str:
        return f"{self.name} {self.column.type.value} {"AUTOINCREMENT" if self.column.is_autoincrement else ""} {"" if self.column.is_nullable else "NOT NULL"}"


class PrimaryKey:
    def __init__(self, type: Type):
        self.type = type
        self.is_autoincrement = False

    def autoincrement(self) -> PrimaryKey:
        self.is_autoincrement = True
        return self


class NamedPrimaryKey:
    def __init__(self, name: str, primary_key: PrimaryKey):
        self.name = name
        self.primary_key = primary_key

    def to_sql_schema(self) -> str:
        return f"{self.name} {self.primary_key.type.value} PRIMARY KEY {"AUTOINCREMENT" if self.primary_key.is_autoincrement else ""} NOT NULL"


class Table:
    table_name: str


T = TypeVar("T", bound=type[Table])


def table(schema: T) -> T:
    if getattr(schema, "_primary_key", None) is not None:
        raise ValueError(
            "The provided table schema cannot contain a field named `primary_key`."
        )

    properties = dir(schema)

    try:
        primary_key_name, primary_key = next(
            (
                (name, value)
                for name in properties
                if isinstance((value := getattr(schema, name)), PrimaryKey)
            ),
        )
    except StopIteration:
        raise ValueError("The provided table schema does not contain a primary key.")

    named_primary_key: NamedPrimaryKey
    if isinstance(primary_key, NamedPrimaryKey):
        named_primary_key = primary_key
    else:
        named_primary_key = NamedPrimaryKey(primary_key_name, primary_key)

    columns: list[tuple[str, NamedColumn]] = [
        (
            name,
            (
                column
                if isinstance(column, NamedColumn)
                else (NamedColumn(name, column))
            ),
        )
        for name in dir(schema)
        if isinstance((column := getattr(schema, name)), Column)
    ]

    setattr(schema, primary_key_name, named_primary_key)

    def get_primary_key(self) -> NamedPrimaryKey:
        return cast(NamedPrimaryKey, getattr(self, primary_key_name))

    setattr(schema, "_primary_key", get_primary_key)

    for property_name, column in columns:
        setattr(schema, property_name, column)

    return schema


def _table_to_sql_schema(named_table) -> str:
    primary_key_schema: NamedPrimaryKey = named_table._primary_key(named_table)

    columns = [
        column
        for column_name in dir(named_table)
        if isinstance((column := getattr(named_table, column_name)), NamedColumn)
    ]
    column_schemas = ",\n    ".join([column.to_sql_schema() for column in columns])

    return f"""
{named_table.table_name}(
{primary_key_schema.to_sql_schema()},
{column_schemas}
)"""


def _table_to_create_query(table: type[Table]) -> str:
    return "CREATE TABLE IF NOT EXISTS " + _table_to_sql_schema(table) + ";"


class Schema:
    def __init__(self, tables: list[type[Table]]):
        self.tables = tables

    def to_create_query(self) -> str:
        return "\n".join([_table_to_create_query(table) for table in self.tables])
