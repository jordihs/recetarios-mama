"""SQLite database: connection management and schema.

Schema v2 stores rich content as markdown TEXT. Older databases are not
supported at all: anything that predates the current schema is wiped on open
(database file and images directory) and recreated fresh, exactly as if the
app had just been installed for the first time.
"""

import shutil
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
        self.conn = self._connect()
        if self._is_outdated():
            self._wipe_all_data()
            self.conn = self._connect()
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _is_outdated(self) -> bool:
        version = self.conn.execute("PRAGMA user_version").fetchone()[0]
        if version >= SCHEMA_VERSION:
            return False
        has_tables = (
            self.conn.execute(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' LIMIT 1"
            ).fetchone()
            is not None
        )
        return has_tables

    def _wipe_all_data(self) -> None:
        """Pre-v2 data is unsupported: erase it all and start from scratch."""
        self.conn.close()
        for suffix in ("", "-wal", "-shm"):
            (self.data_dir / f"recetarios.db{suffix}").unlink(missing_ok=True)
        shutil.rmtree(self.data_dir / "images", ignore_errors=True)

    def _ensure_schema(self) -> None:
        self.conn.executescript(_SCHEMA)
        self.conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        self.conn.commit()

    def close(self) -> None:
        self.conn.close()
