from enum import Enum


def result(result: Enum) -> tuple[dict[str, str], int]:
    message = result.name.lower()
    status_code = int(result.value)

    return {"result": message}, status_code
