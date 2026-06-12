"""SQLite database: connection management, schema, format detection.

Schema v2 stores rich content as markdown TEXT. There is no migration path:
a v1 database is detected (``format == "legacy"``), left untouched, and the
API offers a reset instead (see api/library_status.py).
"""

import sqlite3
from pathlib import Path

SCHEMA_VERSION = 2

_SCHEMA = """
CREATE TABLE IF NOT EXISTS books (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    cover_image TEXT,
    presentation TEXT NOT NULL DEFAULT '',
    note        TEXT,
    position    INTEGER NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS chapters (
    id                TEXT PRIMARY KEY,
    book_id           TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    parent_chapter_id TEXT REFERENCES chapters(id) ON DELETE CASCADE,
    title             TEXT NOT NULL,
    cover_image       TEXT,
    presentation      TEXT NOT NULL DEFAULT '',
    note              TEXT,
    position          INTEGER NOT NULL,
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_chapters_book ON chapters(book_id, parent_chapter_id, position);
CREATE TABLE IF NOT EXISTS recipes (
    id           TEXT PRIMARY KEY,
    chapter_id   TEXT NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    image        TEXT,
    introduction TEXT NOT NULL DEFAULT '',
    ingredients  TEXT NOT NULL DEFAULT '{"servings": null, "groups": []}',
    preparation  TEXT NOT NULL DEFAULT '',
    note         TEXT,
    position     INTEGER NOT NULL,
    created_at   TEXT NOT NULL,
    updated_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_recipes_chapter ON recipes(chapter_id, position);
CREATE TABLE IF NOT EXISTS images (
    hash   TEXT PRIMARY KEY,
    ext    TEXT NOT NULL,
    width  INTEGER,
    height INTEGER
);
CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE VIRTUAL TABLE IF NOT EXISTS recipe_fts USING fts5(
    recipe_id UNINDEXED, title, ingredients, preparation, introduction,
    tokenize = "unicode61 remove_diacritics 2"
);
"""


class Database:
    """Owns the SQLite connection for one data directory."""

    def __init__(self, data_dir: Path):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.path = self.data_dir / "recetarios.db"
        self.conn = sqlite3.connect(self.path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA journal_mode = WAL")
        self.conn.execute("PRAGMA foreign_keys = ON")
        self.format = self._probe_format()
        if self.format == "current":
            self._ensure_schema()

    def _probe_format(self) -> str:
        """"current" for fresh or v2 databases; "legacy" for anything older."""
        version = self.conn.execute("PRAGMA user_version").fetchone()[0]
        if version >= SCHEMA_VERSION:
            return "current"
        has_tables = (
            self.conn.execute(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' LIMIT 1"
            ).fetchone()
            is not None
        )
        return "legacy" if has_tables else "current"

    def _ensure_schema(self) -> None:
        self.conn.executescript(_SCHEMA)
        self.conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        self.conn.commit()

    def close(self) -> None:
        self.conn.close()
