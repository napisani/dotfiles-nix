from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


def normalize_path(value: Path | str) -> str:
    return str(Path(value).expanduser().resolve())


@contextmanager
def connect(db_path: Path | str) -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(Path(db_path))
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        yield conn
        conn.commit()
    finally:
        conn.close()
