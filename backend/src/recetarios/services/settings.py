"""Persistent application settings (FR-033/FR-035)."""

import os
from pathlib import Path

from recetarios.api.errors import ApiError
from recetarios.storage.db import Database

PDF_OUTPUT_DIR = "pdf_output_dir"


def default_pdf_dir() -> str:
    return str(Path.home())


class SettingsService:
    def __init__(self, db: Database):
        self.db = db

    def get_all(self) -> dict:
        rows = self.db.conn.execute("SELECT key, value FROM settings").fetchall()
        settings = {row["key"]: row["value"] for row in rows}
        settings.setdefault(PDF_OUTPUT_DIR, default_pdf_dir())
        return settings

    def get(self, key: str) -> str:
        return self.get_all()[key]

    def update(self, values: dict) -> dict:
        if PDF_OUTPUT_DIR in values:
            validate_output_dir(values[PDF_OUTPUT_DIR])
        for key, value in values.items():
            self.db.conn.execute(
                "INSERT INTO settings(key, value) VALUES (?, ?)"
                " ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                (key, str(value)),
            )
        self.db.conn.commit()
        return self.get_all()


def validate_output_dir(value: str) -> Path:
    path = Path(value)
    if not path.is_dir() or not os.access(path, os.W_OK):
        raise ApiError("output_dir_invalid")
    return path
