"""Library archive: single-file export/import of the whole library (FR-027/028).

Format: ZIP containing `library.json` (versioned, full nested trees) and
`images/<hash>.<ext>`. Import fully validates the manifest, ingests images
(content-addressed, idempotent), and replaces the library inside one SQLite
transaction — failure anywhere leaves the live library untouched.
"""

import json
import zipfile
from datetime import UTC, datetime
from pathlib import Path

from pydantic import TypeAdapter, ValidationError

from recetarios.api.errors import ApiError
from recetarios.models.blocks import ContentBlock, referenced_image_hashes
from recetarios.models.entities import IngredientsList
from recetarios.storage.db import Database
from recetarios.storage.images import ImageStore, ImageStoreError
from recetarios.storage.repository import Repository, _new_id, _now

FORMAT_VERSION = 1

_blocks_adapter = TypeAdapter(list[ContentBlock])


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
        presentation = json.loads(row["presentation"])
        self._collect(presentation, hashes)
        if row["cover_image"]:
            hashes.add(row["cover_image"])
        return {
            "title": row["title"],
            "cover_image": row["cover_image"],
            "presentation": presentation,
            "chapters": self._export_chapters(row["id"], None, hashes),
        }

    def _export_chapters(self, book_id: str, parent_id: str | None, hashes: set[str]) -> list:
        chapters = []
        for row in self.repo.list_chapters(book_id, parent_id):
            presentation = json.loads(row["presentation"])
            self._collect(presentation, hashes)
            if row["cover_image"]:
                hashes.add(row["cover_image"])
            recipes = []
            for recipe_row in self.repo.list_recipes(row["id"]):
                introduction = json.loads(recipe_row["introduction"])
                preparation = json.loads(recipe_row["preparation"])
                self._collect(introduction, hashes)
                self._collect(preparation, hashes)
                if recipe_row["image"]:
                    hashes.add(recipe_row["image"])
                recipes.append(
                    {
                        "title": recipe_row["title"],
                        "image": recipe_row["image"],
                        "introduction": introduction,
                        "ingredients": json.loads(recipe_row["ingredients"]),
                        "preparation": preparation,
                        "note": recipe_row["note"],
                    }
                )
            chapters.append(
                {
                    "title": row["title"],
                    "cover_image": row["cover_image"],
                    "presentation": presentation,
                    "recipes": recipes,
                    "children": self._export_chapters(book_id, row["id"], hashes),
                }
            )
        return chapters

    def _collect(self, blocks: list[dict], hashes: set[str]) -> None:
        try:
            hashes.update(referenced_image_hashes(_blocks_adapter.validate_python(blocks)))
        except ValidationError:
            pass

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
        if not isinstance(manifest, dict) or manifest.get("format_version") != FORMAT_VERSION:
            raise ApiError("archive_invalid")
        books = manifest.get("books")
        if not isinstance(books, list):
            raise ApiError("archive_invalid")

        def validate_chapter(chapter: dict) -> None:
            if not isinstance(chapter.get("title"), str):
                raise ApiError("archive_invalid")
            _blocks_adapter.validate_python(chapter.get("presentation") or [])
            for recipe in chapter.get("recipes") or []:
                if not isinstance(recipe.get("title"), str):
                    raise ApiError("archive_invalid")
                _blocks_adapter.validate_python(recipe.get("introduction") or [])
                _blocks_adapter.validate_python(recipe.get("preparation") or [])
                IngredientsList.model_validate(recipe.get("ingredients") or {})
            for child in chapter.get("children") or []:
                validate_chapter(child)

        try:
            for book in books:
                if not isinstance(book.get("title"), str):
                    raise ApiError("archive_invalid")
                _blocks_adapter.validate_python(book.get("presentation") or [])
                for chapter in book.get("chapters") or []:
                    validate_chapter(chapter)
        except ValidationError as exc:
            raise ApiError("archive_invalid") from exc

    def _insert_book(self, conn, book: dict, position: int) -> None:
        now = _now()
        book_id = _new_id()
        conn.execute(
            "INSERT INTO books(id, title, cover_image, presentation, position,"
            " created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (book_id, book["title"], book.get("cover_image"),
             json.dumps(book.get("presentation") or []), position, now, now),
        )
        self._insert_chapters(conn, book_id, None, book.get("chapters") or [], now)

    def _insert_chapters(self, conn, book_id, parent_id, chapters: list, now: str) -> None:
        for position, chapter in enumerate(chapters):
            chapter_id = _new_id()
            conn.execute(
                "INSERT INTO chapters(id, book_id, parent_chapter_id, title, cover_image,"
                " presentation, position, created_at, updated_at)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (chapter_id, book_id, parent_id, chapter["title"], chapter.get("cover_image"),
                 json.dumps(chapter.get("presentation") or []), position, now, now),
            )
            for recipe_position, recipe in enumerate(chapter.get("recipes") or []):
                conn.execute(
                    "INSERT INTO recipes(id, chapter_id, title, image, introduction,"
                    " ingredients, preparation, note, position, created_at, updated_at)"
                    " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (_new_id(), chapter_id, recipe["title"], recipe.get("image"),
                     json.dumps(recipe.get("introduction") or []),
                     json.dumps(recipe.get("ingredients") or {}),
                     json.dumps(recipe.get("preparation") or []),
                     recipe.get("note"), recipe_position, now, now),
                )
            self._insert_chapters(conn, book_id, chapter_id, chapter.get("children") or [], now)
