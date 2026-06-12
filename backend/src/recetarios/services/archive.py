"""Library archive: single-file export/import of the whole library (FR-027/028).

Format v2: ZIP containing `library.json` (versioned, full nested trees with
markdown content strings and note fields) and `images/<hash>.<ext>`. Archives
with any other `format_version` are rejected (`archive_unsupported_version`,
FR-015) — there is no conversion path. Import fully validates the manifest,
ingests images (content-addressed, idempotent), and replaces the library
inside one SQLite transaction — failure anywhere leaves the live library
untouched.
"""

import json
import zipfile
from datetime import UTC, datetime
from pathlib import Path

from pydantic import ValidationError

from recetarios.api.errors import ApiError
from recetarios.models.entities import IngredientsList
from recetarios.models.markdown import referenced_images
from recetarios.storage.db import Database
from recetarios.storage.images import ImageStore, ImageStoreError
from recetarios.storage.repository import Repository, _new_id, _now

FORMAT_VERSION = 2


class ArchiveService:
    def __init__(self, db: Database, repo: Repository, images: ImageStore):
        self.db = db
        self.repo = repo
        self.images = images

    # ----------------------------------------------------------------- export

    def export(self, target: Path) -> dict:
        books = []
        hashes: set[str] = set()
        for book_row in self.repo.list_books():
            books.append(self._export_book(book_row, hashes))

        manifest = {
            "format_version": FORMAT_VERSION,
            "exported_at": datetime.now(UTC).isoformat(timespec="seconds"),
            "books": books,
        }
        target = Path(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("library.json", json.dumps(manifest, ensure_ascii=False, indent=1))
            for hash_ in sorted(hashes):
                path = self.images.path_for(hash_)
                if path is not None:
                    zf.write(path, f"images/{path.name}")
        return {"path": str(target), "books": len(books)}

    def _export_book(self, row, hashes: set[str]) -> dict:
        hashes.update(referenced_images(row["presentation"]))
        if row["cover_image"]:
            hashes.add(row["cover_image"])
        return {
            "title": row["title"],
            "cover_image": row["cover_image"],
            "presentation": row["presentation"],
            "note": row["note"],
            "chapters": self._export_chapters(row["id"], None, hashes),
        }

    def _export_chapters(self, book_id: str, parent_id: str | None, hashes: set[str]) -> list:
        chapters = []
        for row in self.repo.list_chapters(book_id, parent_id):
            hashes.update(referenced_images(row["presentation"]))
            if row["cover_image"]:
                hashes.add(row["cover_image"])
            recipes = []
            for recipe_row in self.repo.list_recipes(row["id"]):
                hashes.update(referenced_images(recipe_row["introduction"]))
                hashes.update(referenced_images(recipe_row["preparation"]))
                if recipe_row["image"]:
                    hashes.add(recipe_row["image"])
                recipes.append(
                    {
                        "title": recipe_row["title"],
                        "image": recipe_row["image"],
                        "introduction": recipe_row["introduction"],
                        "ingredients": json.loads(recipe_row["ingredients"]),
                        "preparation": recipe_row["preparation"],
                        "note": recipe_row["note"],
                    }
                )
            chapters.append(
                {
                    "title": row["title"],
                    "cover_image": row["cover_image"],
                    "presentation": row["presentation"],
                    "note": row["note"],
                    "recipes": recipes,
                    "children": self._export_chapters(book_id, row["id"], hashes),
                }
            )
        return chapters

    # ----------------------------------------------------------------- import

    def import_replace(self, source: Path, confirm_replace: bool) -> dict:
        if not confirm_replace:
            raise ApiError("archive_confirm_required")
        source = Path(source)
        if not source.is_file():
            raise ApiError("archive_invalid")

        try:
            with zipfile.ZipFile(source) as zf:
                manifest = json.loads(zf.read("library.json").decode("utf-8"))
                self._validate_manifest(manifest)
                # Ingest images first: content-addressed, harmless on abort.
                for name in zf.namelist():
                    if name.startswith("images/") and not name.endswith("/"):
                        try:
                            self.images.ingest(zf.read(name))
                        except ImageStoreError as exc:
                            raise ApiError("archive_invalid") from exc
        except (zipfile.BadZipFile, KeyError, UnicodeDecodeError, ValueError) as exc:
            raise ApiError("archive_invalid") from exc

        # Atomic replace: everything below runs in one transaction.
        conn = self.db.conn
        try:
            with conn:
                conn.execute("DELETE FROM books")
                conn.execute("DELETE FROM recipe_fts")
                for position, book in enumerate(manifest["books"]):
                    self._insert_book(conn, book, position)
        except Exception as exc:
            raise ApiError("archive_invalid") from exc
        self.repo.rebuild_fts()
        return {"books": len(manifest["books"])}

    def _validate_manifest(self, manifest: dict) -> None:
        if not isinstance(manifest, dict):
            raise ApiError("archive_invalid")
        if manifest.get("format_version") != FORMAT_VERSION:
            raise ApiError("archive_unsupported_version")
        books = manifest.get("books")
        if not isinstance(books, list):
            raise ApiError("archive_invalid")

        def require_markdown(value) -> None:
            if value is not None and not isinstance(value, str):
                raise ApiError("archive_invalid")

        def require_note(value) -> None:
            if value is not None and not isinstance(value, str):
                raise ApiError("archive_invalid")

        def validate_chapter(chapter: dict) -> None:
            if not isinstance(chapter.get("title"), str):
                raise ApiError("archive_invalid")
            require_markdown(chapter.get("presentation"))
            require_note(chapter.get("note"))
            for recipe in chapter.get("recipes") or []:
                if not isinstance(recipe.get("title"), str):
                    raise ApiError("archive_invalid")
                require_markdown(recipe.get("introduction"))
                require_markdown(recipe.get("preparation"))
                require_note(recipe.get("note"))
                IngredientsList.model_validate(recipe.get("ingredients") or {})
            for child in chapter.get("children") or []:
                validate_chapter(child)

        try:
            for book in books:
                if not isinstance(book.get("title"), str):
                    raise ApiError("archive_invalid")
                require_markdown(book.get("presentation"))
                require_note(book.get("note"))
                for chapter in book.get("chapters") or []:
                    validate_chapter(chapter)
        except ValidationError as exc:
            raise ApiError("archive_invalid") from exc

    def _insert_book(self, conn, book: dict, position: int) -> None:
        now = _now()
        book_id = _new_id()
        conn.execute(
            "INSERT INTO books(id, title, cover_image, presentation, note, position,"
            " created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (book_id, book["title"], book.get("cover_image"),
             book.get("presentation") or "", book.get("note"), position, now, now),
        )
        self._insert_chapters(conn, book_id, None, book.get("chapters") or [], now)

    def _insert_chapters(self, conn, book_id, parent_id, chapters: list, now: str) -> None:
        for position, chapter in enumerate(chapters):
            chapter_id = _new_id()
            conn.execute(
                "INSERT INTO chapters(id, book_id, parent_chapter_id, title, cover_image,"
                " presentation, note, position, created_at, updated_at)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (chapter_id, book_id, parent_id, chapter["title"], chapter.get("cover_image"),
                 chapter.get("presentation") or "", chapter.get("note"), position, now, now),
            )
            for recipe_position, recipe in enumerate(chapter.get("recipes") or []):
                conn.execute(
                    "INSERT INTO recipes(id, chapter_id, title, image, introduction,"
                    " ingredients, preparation, note, position, created_at, updated_at)"
                    " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (_new_id(), chapter_id, recipe["title"], recipe.get("image"),
                     recipe.get("introduction") or "",
                     json.dumps(recipe.get("ingredients") or {}),
                     recipe.get("preparation") or "",
                     recipe.get("note"), recipe_position, now, now),
                )
            self._insert_chapters(conn, book_id, chapter_id, chapter.get("children") or [], now)
