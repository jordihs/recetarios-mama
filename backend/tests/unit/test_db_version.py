"""Foundational: schema v2 creation and v1 detection (no migration, no touching)."""

import sqlite3

from recetarios.storage.db import SCHEMA_VERSION, Database

# Minimal v1 footprint: what feature 002's Database left on disk.
_V1_SCHEMA = """
CREATE TABLE books (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    cover_image TEXT,
    presentation TEXT NOT NULL DEFAULT '[]',
    position    INTEGER NOT NULL,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
PRAGMA user_version = 1;
"""


def _make_v1_db(data_dir):
    path = data_dir / "recetarios.db"
    conn = sqlite3.connect(path)
    conn.executescript(_V1_SCHEMA)
    conn.commit()
    conn.close()
    return path


def test_fresh_database_is_created_at_v2(tmp_path):
    db = Database(tmp_path)
    try:
        assert SCHEMA_VERSION == 2
        assert db.format == "current"
        assert db.conn.execute("PRAGMA user_version").fetchone()[0] == 2
        book_cols = {r[1] for r in db.conn.execute("PRAGMA table_info(books)")}
        chapter_cols = {r[1] for r in db.conn.execute("PRAGMA table_info(chapters)")}
        assert "note" in book_cols
        assert "note" in chapter_cols
    finally:
        db.close()


def test_fresh_content_defaults_are_empty_markdown(tmp_path):
    db = Database(tmp_path)
    try:
        db.conn.execute(
            "INSERT INTO books (id, title, position, created_at, updated_at)"
            " VALUES ('b1', 'Libro', 0, 'now', 'now')"
        )
        row = db.conn.execute("SELECT presentation, note FROM books").fetchone()
        assert row["presentation"] == ""
        assert row["note"] is None
    finally:
        db.close()


def test_v1_database_is_detected_and_never_touched(tmp_path):
    _make_v1_db(tmp_path)
    db = Database(tmp_path)
    try:
        assert db.format == "legacy"
        # Untouched: version still 1, no v2 columns, no new tables.
        assert db.conn.execute("PRAGMA user_version").fetchone()[0] == 1
        book_cols = {r[1] for r in db.conn.execute("PRAGMA table_info(books)")}
        assert "note" not in book_cols
        tables = {
            r[0]
            for r in db.conn.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        assert "chapters" not in tables
    finally:
        db.close()


def test_reopening_a_v2_database_stays_current(tmp_path):
    Database(tmp_path).close()
    db = Database(tmp_path)
    try:
        assert db.format == "current"
        assert db.conn.execute("PRAGMA user_version").fetchone()[0] == 2
    finally:
        db.close()
