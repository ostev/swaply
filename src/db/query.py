from dataclasses import dataclass
from enum import Enum

from db.schema import NamedColumn, Table


class BinaryOperator(Enum):
    EQ = "="
    GT = ">"
    LT = "<"
    GTE = ">="
    LTE = "<="
    NEQ = "<>"
    BETWEEN = "BETWEEN"
    LIKE = "LIKE"
    IN = "IN"


type Term = NamedColumn | str | int | float


@dataclass
class Condition:
    left: Term
    operator: BinaryOperator
    right: Term


def lt(left: Term, right: Term):
    Condition(left, BinaryOperator.LT, right)
    return Condition(left, BinaryOperator.LT, right)


def eq(left: Term, right: Term):
    return Condition(left, BinaryOperator.EQ, right)


def gt(left: Term, right: Term):
    return Condition(left, BinaryOperator.GT, right)


def gte(left: Term, right: Term):
    return Condition(left, BinaryOperator.GTE, right)


def lte(left: Term, right: Term):
    return Condition(left, BinaryOperator.LTE, right)


def neq(left: Term, right: Term):
    return Condition(left, BinaryOperator.NEQ, right)


def between(left: Term, right: Term):
    return Condition(left, BinaryOperator.BETWEEN, right)


def like(left: Term, right: Term):
    return Condition(left, BinaryOperator.LIKE, right)


def in_(left: Term, right: Term):
    return Condition(left, BinaryOperator.IN, right)


class Select:
    def __init__(self, columns: list[NamedColumn], table: Table):
        self._where = None
        self._columns = columns
        self._table = table

    def where(self, condition: Condition):
        pass

    def where_or(self, condition):
        pass
