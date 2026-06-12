"""Schema v2 creation; pre-v2 data is wiped on open as if it never existed."""

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
INSERT INTO books VALUES ('b1', 'Libro viejo', NULL, '[]', 0, 'x', 'x');
PRAGMA user_version = 1;
"""


def _make_v1_db(data_dir):
    conn = sqlite3.connect(data_dir / "recetarios.db")
    conn.executescript(_V1_SCHEMA)
    conn.commit()
    conn.close()


def test_fresh_database_is_created_at_v2(tmp_path):
    db = Database(tmp_path)
    try:
        assert SCHEMA_VERSION == 2
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


def test_pre_v2_database_is_wiped_and_recreated(tmp_path):
    """Old data simply disappears: fresh v2 schema, no rows, no images."""
    _make_v1_db(tmp_path)
    images_dir = tmp_path / "images"
    images_dir.mkdir()
    (images_dir / ("a" * 64 + ".png")).write_bytes(b"old-bytes")

    db = Database(tmp_path)
    try:
        assert db.conn.execute("PRAGMA user_version").fetchone()[0] == 2
        assert db.conn.execute("SELECT COUNT(*) FROM books").fetchone()[0] == 0
        book_cols = {r[1] for r in db.conn.execute("PRAGMA table_info(books)")}
        assert "note" in book_cols  # the v2 schema, not the old one
        assert not (images_dir / ("a" * 64 + ".png")).exists()
    finally:
        db.close()


def test_reopening_a_v2_database_keeps_its_data(tmp_path):
    db = Database(tmp_path)
    db.conn.execute(
        "INSERT INTO books (id, title, position, created_at, updated_at)"
        " VALUES ('b1', 'Se conserva', 0, 'now', 'now')"
    )
    db.conn.commit()
    db.close()

    db = Database(tmp_path)
    try:
        assert db.conn.execute("PRAGMA user_version").fetchone()[0] == 2
        titles = [r["title"] for r in db.conn.execute("SELECT title FROM books")]
        assert titles == ["Se conserva"]
    finally:
        db.close()
