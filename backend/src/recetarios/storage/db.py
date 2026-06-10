"""SQLite database: connection management, schema, migrations."""

import sqlite3
from pathlib import Path

SCHEMA_VERSION = 1

_SCHEMA = """
CREATE TABLE IF NOT EXISTS books (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    cover_image TEXT,
    presentation TEXT NOT NULL DEFAULT '[]',
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
    presentation      TEXT NOT NULL DEFAULT '[]',
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
    introduction TEXT NOT NULL DEFAULT '[]',
    ingredients  TEXT NOT NULL DEFAULT '{"servings": null, "groups": []}',
    preparation  TEXT NOT NULL DEFAULT '[]',
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
        self._migrate()

    def _migrate(self) -> None:
        version = self.conn.execute("PRAGMA user_version").fetchone()[0]
        if version < SCHEMA_VERSION:
            self.conn.executescript(_SCHEMA)
            self.conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
            self.conn.commit()

    def close(self) -> None:
        self.conn.close()
