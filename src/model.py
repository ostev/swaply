from auth.session import Session
from db.schema import Column, PrimaryKey, Schema, table
from auth.user import User
from listing import Listing, TicketType


# @table
# class Ticket:
#     table_name = "items"
#     id = PrimaryKey.integer().autoincrement()

#     user_id = Column.foreign(User.id)
#     listing_id = Column.foreign(Listing.id)

#     type = Column.integer()


schema = Schema([Session, User, Listing, TicketType])
