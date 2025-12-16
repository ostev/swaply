from enum import Enum
from auth.session import Session
from db.schema import Column, PrimaryKey, Schema, table
from auth.user import User


@table
class Event:
    table_name = "events"
    id = PrimaryKey.integer().autoincrement()
    manager = Column.foreign(User.id)

    name = Column.text()
    date = Column.text()

    # Stored as a JSON array of strings
    ticket_types = Column.text()


@table
class Ticket:
    table_name = "tickets"
    id = PrimaryKey.integer().autoincrement()

    user_id = Column.foreign(User.id)
    event_id = Column.foreign(Event.id)

    type = Column.integer()


schema = Schema([Session, User, Event, Ticket])
