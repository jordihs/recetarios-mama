"""Persistence layer over SQLite, including the FTS5 search index sync."""

import json
import uuid
from datetime import UTC, datetime
from sqlite3 import Row

from recetarios.models.markdown import plain_text
from recetarios.storage.db import Database


def _ingredients_plain(ingredients_json: str) -> str:
    try:
        data = json.loads(ingredients_json)
    except ValueError:
        return ""
    parts = []
    for group in data.get("groups") or []:
        if group.get("title"):
            parts.append(group["title"])
        parts.extend(group.get("items") or [])
    return "\n".join(parts)


def _now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


def _new_id() -> str:
    return str(uuid.uuid4())


class Repository:
    def __init__(self, db: Database):
        self.db = db
        self.conn = db.conn

    # ------------------------------------------------------------------ books

    def list_books(self) -> list[Row]:
        return self.conn.execute("SELECT * FROM books ORDER BY position").fetchall()

    def get_book(self, book_id: str) -> Row | None:
        return self.conn.execute("SELECT * FROM books WHERE id = ?", (book_id,)).fetchone()

    def create_book(
        self,
        title: str,
        cover_image: str | None,
        presentation: str,
        note: str | None,
    ) -> str:
        book_id = _new_id()
        now = _now()
        position = self.conn.execute(
            "SELECT COALESCE(MAX(position) + 1, 0) FROM books"
        ).fetchone()[0]
        self.conn.execute(
            "INSERT INTO books(id, title, cover_image, presentation, note, position,"
            " created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (book_id, title, cover_image, presentation, note, position, now, now),
        )
        self.conn.commit()
        return book_id

    def update_book(
        self,
        book_id: str,
        title: str,
        cover_image: str | None,
        presentation: str,
        note: str | None,
    ) -> None:
        self.conn.execute(
            "UPDATE books SET title = ?, cover_image = ?, presentation = ?, note = ?,"
            " updated_at = ? WHERE id = ?",
            (title, cover_image, presentation, note, _now(), book_id),
        )
        self.conn.commit()

    def set_book_cover(self, book_id: str, cover_image: str) -> None:
        self.conn.execute(
            "UPDATE books SET cover_image = ? WHERE id = ?", (cover_image, book_id)
        )
        self.conn.commit()

    def delete_book(self, book_id: str) -> None:
        self.conn.execute("DELETE FROM books WHERE id = ?", (book_id,))
        self._fts_purge_orphans()
        self.conn.commit()

    def reorder_books(self, ids: list[str]) -> bool:
        current = {row["id"] for row in self.list_books()}
        if set(ids) != current or len(ids) != len(current):
            return False
        for position, book_id in enumerate(ids):
            self.conn.execute(
                "UPDATE books SET position = ? WHERE id = ?", (position, book_id)
            )
        self.conn.commit()
        return True

    # --------------------------------------------------------------- chapters

    def list_chapters(self, book_id: str, parent_chapter_id: str | None) -> list[Row]:
        if parent_chapter_id is None:
            return self.conn.execute(
                "SELECT * FROM chapters WHERE book_id = ? AND parent_chapter_id IS NULL"
                " ORDER BY position",
                (book_id,),
            ).fetchall()
        return self.conn.execute(
            "SELECT * FROM chapters WHERE book_id = ? AND parent_chapter_id = ?"
            " ORDER BY position",
            (book_id, parent_chapter_id),
        ).fetchall()

    def get_chapter(self, chapter_id: str) -> Row | None:
        return self.conn.execute(
            "SELECT * FROM chapters WHERE id = ?", (chapter_id,)
        ).fetchone()

    def chapter_has_subchapters(self, chapter_id: str) -> bool:
        row = self.conn.execute(
            "SELECT 1 FROM chapters WHERE parent_chapter_id = ? LIMIT 1", (chapter_id,)
        ).fetchone()
        return row is not None

    def chapter_recipe_count(self, chapter_id: str) -> int:
        return self.conn.execute(
            "SELECT COUNT(*) FROM recipes WHERE chapter_id = ?", (chapter_id,)
        ).fetchone()[0]

    def create_chapter(
        self,
        book_id: str,
        parent_chapter_id: str | None,
        title: str,
        cover_image: str | None,
        presentation: str,
        note: str | None,
    ) -> str:
        chapter_id = _new_id()
        now = _now()
        position = self.conn.execute(
            "SELECT COALESCE(MAX(position) + 1, 0) FROM chapters"
            " WHERE book_id = ? AND parent_chapter_id IS ?",
            (book_id, parent_chapter_id),
        ).fetchone()[0]
        self.conn.execute(
            "INSERT INTO chapters(id, book_id, parent_chapter_id, title, cover_image,"
            " presentation, note, position, created_at, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                chapter_id,
                book_id,
                parent_chapter_id,
                title,
                cover_image,
                presentation,
                note,
                position,
                now,
                now,
            ),
        )
        self.conn.commit()
        return chapter_id

    def update_chapter(
        self,
        chapter_id: str,
        parent_chapter_id: str | None,
        title: str,
        cover_image: str | None,
        presentation: str,
        note: str | None,
    ) -> None:
        self.conn.execute(
            "UPDATE chapters SET parent_chapter_id = ?, title = ?, cover_image = ?,"
            " presentation = ?, note = ?, updated_at = ? WHERE id = ?",
            (
                parent_chapter_id,
                title,
                cover_image,
                presentation,
                note,
                _now(),
                chapter_id,
            ),
        )
        self.conn.commit()

    def set_chapter_cover(self, chapter_id: str, cover_image: str) -> None:
        self.conn.execute(
            "UPDATE chapters SET cover_image = ? WHERE id = ?", (cover_image, chapter_id)
        )
        self.conn.commit()

    def delete_chapter(self, chapter_id: str) -> None:
        self.conn.execute("DELETE FROM chapters WHERE id = ?", (chapter_id,))
        self._fts_purge_orphans()
        self.conn.commit()

    def reorder_chapters(
        self, book_id: str, parent_chapter_id: str | None, ids: list[str]
    ) -> bool:
        current = {row["id"] for row in self.list_chapters(book_id, parent_chapter_id)}
        if set(ids) != current or len(ids) != len(current):
            return False
        for position, chapter_id in enumerate(ids):
            self.conn.execute(
                "UPDATE chapters SET position = ? WHERE id = ?", (position, chapter_id)
            )
        self.conn.commit()
        return True

    # ---------------------------------------------------------------- recipes

    def list_recipes(self, chapter_id: str) -> list[Row]:
        return self.conn.execute(
            "SELECT * FROM recipes WHERE chapter_id = ? ORDER BY position", (chapter_id,)
        ).fetchall()

    def get_recipe(self, recipe_id: str) -> Row | None:
        return self.conn.execute(
            "SELECT * FROM recipes WHERE id = ?", (recipe_id,)
        ).fetchone()

    def create_recipe(
        self,
        chapter_id: str,
        title: str,
        image: str | None,
        introduction: str,
        ingredients: dict,
        preparation: str,
        note: str | None,
    ) -> str:
        recipe_id = _new_id()
        now = _now()
        position = self.conn.execute(
            "SELECT COALESCE(MAX(position) + 1, 0) FROM recipes WHERE chapter_id = ?",
            (chapter_id,),
        ).fetchone()[0]
        self.conn.execute(
            "INSERT INTO recipes(id, chapter_id, title, image, introduction, ingredients,"
            " preparation, note, position, created_at, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                recipe_id,
                chapter_id,
                title,
                image,
                introduction,
                json.dumps(ingredients),
                preparation,
                note,
                position,
                now,
                now,
            ),
        )
        self._fts_upsert(
            recipe_id, title, introduction, json.dumps(ingredients), preparation, note
        )
        self.conn.commit()
        return recipe_id

    def update_recipe(
        self,
        recipe_id: str,
        title: str,
        image: str | None,
        introduction: str,
        ingredients: dict,
        preparation: str,
        note: str | None,
    ) -> None:
        self.conn.execute(
            "UPDATE recipes SET title = ?, image = ?, introduction = ?, ingredients = ?,"
            " preparation = ?, note = ?, updated_at = ? WHERE id = ?",
            (
                title,
                image,
                introduction,
                json.dumps(ingredients),
                preparation,
                note,
                _now(),
                recipe_id,
            ),
        )
        self._fts_upsert(
            recipe_id, title, introduction, json.dumps(ingredients), preparation, note
        )
        self.conn.commit()

    def delete_recipe(self, recipe_id: str) -> None:
        self.conn.execute("DELETE FROM recipes WHERE id = ?", (recipe_id,))
        self._fts_delete(recipe_id)
        self.conn.commit()

    def _fts_purge_orphans(self) -> None:
        self.conn.execute(
            "DELETE FROM recipe_fts WHERE recipe_id NOT IN (SELECT id FROM recipes)"
        )

    def reorder_recipes(self, chapter_id: str, ids: list[str]) -> bool:
        current = {row["id"] for row in self.list_recipes(chapter_id)}
        if set(ids) != current or len(ids) != len(current):
            return False
        for position, recipe_id in enumerate(ids):
            self.conn.execute(
                "UPDATE recipes SET position = ? WHERE id = ?", (position, recipe_id)
            )
        self.conn.commit()
        return True

    # ----------------------------------------------------------------- search

    def _fts_upsert(
        self,
        recipe_id: str,
        title: str,
        introduction: str,
        ingredients: str,
        preparation: str,
        note: str | None,
    ) -> None:
        # The note is searchable too; it rides on the introduction column.
        introduction_text = plain_text(introduction)
        if note:
            introduction_text = f"{introduction_text}\n{note}".strip()
        self.conn.execute("DELETE FROM recipe_fts WHERE recipe_id = ?", (recipe_id,))
        self.conn.execute(
            "INSERT INTO recipe_fts(recipe_id, title, ingredients, preparation, introduction)"
            " VALUES (?, ?, ?, ?, ?)",
            (
                recipe_id,
                title,
                _ingredients_plain(ingredients),
                plain_text(preparation),
                introduction_text,
            ),
        )

    def _fts_delete(self, recipe_id: str) -> None:
        self.conn.execute("DELETE FROM recipe_fts WHERE recipe_id = ?", (recipe_id,))

    def rebuild_fts(self) -> None:
        """Full index rebuild — used after archive restore and bulk imports."""
        self.conn.execute("DELETE FROM recipe_fts")
        for row in self.conn.execute(
            "SELECT id, title, introduction, ingredients, preparation, note FROM recipes"
        ).fetchall():
            self._fts_upsert(
                row["id"], row["title"], row["introduction"], row["ingredients"],
                row["preparation"], row["note"],
            )
        self.conn.commit()

    def search(self, query: str, limit: int = 50) -> list[Row]:
        tokens = [t for t in query.split() if t.strip('"*')]
        if not tokens:
            return []
        match = " ".join('"{}"*'.format(t.replace('"', "")) for t in tokens)
        return self.conn.execute(
            "SELECT r.id AS recipe_id, r.title, r.chapter_id,"
            " snippet(recipe_fts, -1, '', '', '…', 12) AS snippet"
            " FROM recipe_fts JOIN recipes r ON r.id = recipe_fts.recipe_id"
            " WHERE recipe_fts MATCH ? ORDER BY bm25(recipe_fts) LIMIT ?",
            (match, limit),
        ).fetchall()
