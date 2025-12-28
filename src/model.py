from auth.session import Session
from db.schema import Column, PrimaryKey, Schema, table
from auth.user import User
from event import Event, TicketType


# @table
# class Ticket:
#     table_name = "tickets"
#     id = PrimaryKey.integer().autoincrement()

#     user_id = Column.foreign(User.id)
#     event_id = Column.foreign(Event.id)

#     type = Column.integer()


schema = Schema([Session, User, Event, TicketType])
