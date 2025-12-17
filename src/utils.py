from enum import Enum
import json
import re
from typing import Any


def result(
    result: Enum, json_response: dict[str, Any] = {}
) -> tuple[dict[str, Any], int]:
    message = result.name.lower()
    status_code = int(result.value)

    return {"result": message} | json_response, status_code


def normalise_json_str_array(input: str) -> str:
    return json.dumps(map(str, json.loads(input)))


def check_sql_identifier(name: str) -> str:
    if len(re.findall(r"""^([[:alpha:]_][[:alnum:]_]*|("[^"]*")+)$""", name)) == 1:
        return name
    else:
        raise ValueError(f"Illegal SQL identifier: {name}")
