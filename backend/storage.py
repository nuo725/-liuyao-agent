from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any


class SQLiteStateStore:
    """Small SQLite-backed state snapshot store for local backend development."""

    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path

    def load(self) -> dict[str, Any] | None:
        self._ensure_schema()
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                "select value from app_state where key = ?",
                ("store",),
            ).fetchone()
        if not row:
            return None
        try:
            data = json.loads(row[0])
        except json.JSONDecodeError:
            return None
        return data if isinstance(data, dict) else None

    def save(self, data: dict[str, Any]) -> None:
        self._ensure_schema()
        encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                insert into app_state(key, value, updated_at)
                values (?, ?, datetime('now'))
                on conflict(key) do update set
                  value = excluded.value,
                  updated_at = excluded.updated_at
                """,
                ("store", encoded),
            )
            conn.commit()

    def _ensure_schema(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                create table if not exists app_state (
                  key text primary key,
                  value text not null,
                  updated_at text not null default (datetime('now'))
                )
                """
            )
            conn.commit()
