from enum import Enum
from typing import Protocol, Self, cast


class Type(Enum):
    INTEGER = "INTEGER"
    TEXT = "TEXT"
    BLOB = "BLOB"
    NUMERIC = "NUMERIC"


type ForeignReference = NamedColumn | NamedPrimaryKey


class Table(Protocol):
    table_name: str


class Column:
    """
    Defines a column in a table. This is the type you should use to create columns
    in your schemas.
    """

    def __init__(self, type: Type):
        self.type = type
        self.is_autoincrement = False
        self.is_nullable = False
        self.foreign_reference: ForeignReference | None = None

    def autoincrement(self) -> Self:
        self.is_autoincrement = True
        return self

    def nullable(self) -> Self:
        self.is_nullable = True
        return self

    def references(self, column) -> Self:
        if not isinstance(column, NamedColumn) and not isinstance(
            column, NamedPrimaryKey
        ):
            raise ValueError("Column in foreign reference must be named.")

        self.foreign_reference = column
        return self

    @classmethod
    def integer(cls) -> Self:
        return cls(Type.INTEGER)

    @classmethod
    def text(cls) -> Self:
        return cls(Type.TEXT)

    @classmethod
    def blob(cls) -> Self:
        return cls(Type.BLOB)

    @classmethod
    def numeric(cls) -> Self:
        return cls(Type.NUMERIC)

    @classmethod
    def foreign(cls, named_column) -> Self:
        return cls(named_column.column.type).references(named_column)


class NamedColumn:
    """
    An internal class that is used to bind colums to names within a table.
    """

    def __init__(self, name: str, column: Column, table: type[Table]):
        self.name = name
        self.column = column
        self.table = table

    def to_sql_schema(self) -> str:
        autoincrement = " AUTOINCREMENT" if self.column.is_autoincrement else ""
        nullable = "" if self.column.is_nullable else " NOT NULL"

        if self.column.foreign_reference is None:
            foreign_reference = ""
        else:
            foreign_reference = f" REFERENCES {self.column.foreign_reference.table.table_name}({self.column.foreign_reference.name})"
        return f"{self.name} {self.column.type.value}{autoincrement}{nullable}{foreign_reference}"


class PrimaryKey:
    """
    Represents a table's primary key
    """

    def __init__(self, type: Type):
        self.type = type
        self.is_autoincrement = False

    def autoincrement(self) -> Self:
        self.is_autoincrement = True
        return self

    @classmethod
    def integer(cls) -> Self:
        return cls(Type.INTEGER)

    @classmethod
    def text(cls) -> Self:
        return cls(Type.TEXT)

    @classmethod
    def blob(cls) -> Self:
        return cls(Type.BLOB)


class NamedPrimaryKey:
    """
    An internal class that is used to bind primary keys to names within a table.
    """

    def __init__(self, name: str, primary_key: PrimaryKey, table: type[Table]):
        self.name = name
        self.column = primary_key
        self.table = table

    def to_sql_schema(self) -> str:
        return f"{self.name} {self.column.type.value} PRIMARY KEY{" AUTOINCREMENT" if self.column.is_autoincrement else ""} NOT NULL"


def table[T: type[Table]](schema: T) -> T:
    """
    Use this as an @decorator on a class with your table schema.
    """

    # Both of these fields are reserved for internal use
    if getattr(schema, "_primary_key", None) is not None:
        raise ValueError(
            "The provided table schema cannot contain a field named `_primary_key`."
        )

    if getattr(schema, "_columns", None) is not None:
        raise ValueError(
            "The provided table schema cannot contain a field named `_columns`."
        )

    # Get the list of name-column pairs
    properties = dir(schema)

    try:
        # Find the primary key
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
        named_primary_key = NamedPrimaryKey(primary_key_name, primary_key, schema)

    columns_with_property_names: list[tuple[str, NamedColumn]] = [
        (
            name,
            (
                column
                if isinstance(column, NamedColumn)
                else (NamedColumn(name, column, schema))
            ),
        )
        for name in dir(schema)
        if isinstance((column := getattr(schema, name)), Column)
    ]

    setattr(schema, primary_key_name, named_primary_key)

    def get_primary_key(self) -> NamedPrimaryKey:
        return cast(NamedPrimaryKey, getattr(self, primary_key_name))

    setattr(schema, "_primary_key", get_primary_key)

    for property_name, column in columns_with_property_names:
        setattr(schema, property_name, column)

    columns = [column for _, column in columns_with_property_names]
    setattr(schema, "_columns", columns)

    return schema


def _table_to_sql_schema(named_table) -> str:
    """
    Converts a table schema class into an SQL creation schema.
    """
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
    """
    Converts a table schema class into an SQL creation query.
    """
    return "CREATE TABLE IF NOT EXISTS " + _table_to_sql_schema(table) + ";"


class Schema:
    """
    Represents all the tables in the application.
    """

    def __init__(self, tables: list[type[Table]]):
        self.tables = tables

    def to_create_query(self) -> str:
        """
        Transforms the scehma into an SQL creation query.
        """
        return "\n".join([_table_to_create_query(table) for table in self.tables])
