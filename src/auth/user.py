from enum import Enum
from db.schema import Column, PrimaryKey, table


@table
class User:
    table_name = "users"
    id = PrimaryKey.integer().autoincrement()

    email = Column.text()
    hashed_password = Column.text()

    privilege_level = Column.integer()


class PrivilegeLevel(Enum):
    NORMAL = 0
    ADMIN = 1
