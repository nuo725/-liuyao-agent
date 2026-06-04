from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ValidationErrorInfo:
    code: str
    message: str
    field: str | None = None

    def to_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {"code": self.code, "message": self.message}
        if self.field:
            payload["field"] = self.field
        return payload


def non_empty_string(value: Any, field: str, *, max_length: int = 500) -> str | ValidationErrorInfo:
    text = str(value or "").strip()
    if not text:
        return ValidationErrorInfo("40001", f"{field} is required", field)
    if len(text) > max_length:
        return ValidationErrorInfo("40001", f"{field} is too long", field)
    return text


def optional_string(value: Any, field: str, *, max_length: int = 500) -> str | None | ValidationErrorInfo:
    if value is None:
        return None
    text = str(value).strip()
    if len(text) > max_length:
        return ValidationErrorInfo("40001", f"{field} is too long", field)
    return text


def hexagram_lines(value: Any) -> list[int] | ValidationErrorInfo:
    if not isinstance(value, list) or len(value) != 6:
        return ValidationErrorInfo("40001", "lines must contain exactly 6 values", "lines")
    lines: list[int] = []
    for item in value:
        try:
            line = int(item)
        except (TypeError, ValueError):
            return ValidationErrorInfo("40001", "line values must be 0 or 1", "lines")
        if line not in {0, 1}:
            return ValidationErrorInfo("40001", "line values must be 0 or 1", "lines")
        lines.append(line)
    return lines


def moving_lines(value: Any) -> list[int] | ValidationErrorInfo:
    if value is None:
        return []
    if not isinstance(value, list):
        return ValidationErrorInfo("40001", "movingLines must be a list", "movingLines")
    result: list[int] = []
    for item in value:
        try:
            line = int(item)
        except (TypeError, ValueError):
            return ValidationErrorInfo("40001", "movingLines values must be integers from 1 to 6", "movingLines")
        if line < 1 or line > 6:
            return ValidationErrorInfo("40001", "movingLines values must be from 1 to 6", "movingLines")
        if line not in result:
            result.append(line)
    return result


def choice(value: Any, field: str, allowed: set[str]) -> str | ValidationErrorInfo:
    text = str(value or "").strip()
    if text not in allowed:
        return ValidationErrorInfo("40001", f"{field} must be one of: {', '.join(sorted(allowed))}", field)
    return text
