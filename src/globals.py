import typing
import flask

from db import Database


if typing.TYPE_CHECKING:
    from flask.ctx import _AppCtxGlobals

    class CustomGlobals(_AppCtxGlobals):
        db: Database

    g = CustomGlobals()
else:
    g = flask.g
