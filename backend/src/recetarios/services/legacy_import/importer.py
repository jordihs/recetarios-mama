"""Legacy import orchestration (FR-022..FR-026).

Resolves `./imgs/...` references relative to the source document, copies the
files into the content-addressed store, maps the whole RECETARIO tree, and
persists it. On any failure the partially created book is deleted (cascade),
leaving the library unchanged.
"""

from pathlib import Path

from recetarios.api.errors import ApiError
from recetarios.services.legacy_import.mapper import map_introduccion, map_recipe
from recetarios.services.legacy_import.parser import as_list, clean_text, load_document
from recetarios.services.library import LibraryService, _dump_blocks
from recetarios.storage.images import ImageStore, ImageStoreError
from recetarios.storage.repository import Repository


class _ImageResolver:
    """Resolves legacy relative srcs to store hashes; tracks misses."""

    def __init__(self, base_dir: Path, images: ImageStore):
        self.base_dir = base_dir
        self.images = images
        self.resolved: dict[str, str | None] = {}
        self.missing: list[str] = []
        self.imported = 0

    def __call__(self, src: str) -> str | None:
        if src in self.resolved:
            return self.resolved[src]
        hash_ = self._ingest(src)
        self.resolved[src] = hash_
        if hash_ is None:
            self.missing.append(src)
        else:
            self.imported += 1
        return hash_

    def _ingest(self, src: str) -> str | None:
        candidate = self._find_file(src)
        if candidate is None:
            return None
        try:
            return self.images.ingest_file(candidate)["hash"]
        except (OSError, ImageStoreError):
            return None

    def _find_file(self, src: str) -> Path | None:
        relative = src.strip().lstrip("./").replace("\\", "/")
        path = self.base_dir / relative
        if path.is_file():
            return path
        # Case-insensitive fallback (legacy data was authored on Windows).
        parent = path.parent
        if parent.is_dir():
            lowered = path.name.lower()
            for entry in parent.iterdir():
                if entry.name.lower() == lowered:
                    return entry
        return None


class LegacyImporter:
    def __init__(self, repo: Repository, images: ImageStore, library: LibraryService):
        self.repo = repo
        self.images = images
        self.library = library

    def inspect(self, path: str) -> dict:
        document = load_document(Path(path))
        title = clean_text(document.get("TITULO"))
        collision = any(row["title"] == title for row in self.repo.list_books())
        return {"book_title": title, "collision": collision}

    def run(self, path: str, on_collision: str) -> dict:
        source = Path(path)
        document = load_document(source)
        title = clean_text(document.get("TITULO"))

        if on_collision == "replace":
            for row in self.repo.list_books():
                if row["title"] == title:
                    self.repo.delete_book(row["id"])

        resolver = _ImageResolver(source.parent, self.images)
        counters = {"chapters": 0, "recipes": 0}
        book_id = self.repo.create_book(
            title, None, _dump_blocks(map_introduccion(document.get("INTRODUCCION"), resolver))
        )
        try:
            self._import_chapters(book_id, None, document.get("CAPITULO"), resolver, counters)
            root_recipes = as_list(document.get("RECETA"))
            if root_recipes:
                chapter_id = self.repo.create_chapter(book_id, None, title, None, [])
                counters["chapters"] += 1
                self._import_recipes(chapter_id, root_recipes, resolver, counters)
        except Exception:
            # FR-026: never leave a half-imported book behind.
            self.repo.delete_book(book_id)
            raise

        return {
            "book_id": book_id,
            "report": {
                "chapters": counters["chapters"],
                "recipes": counters["recipes"],
                "images_imported": resolver.imported,
                "images_missing": resolver.missing,
            },
        }

    def _import_chapters(self, book_id, parent_id, chapters, resolver, counters) -> None:
        for chapter in as_list(chapters):
            name = clean_text((chapter.get("@attributes") or {}).get("nombre")) or "(capítulo)"
            presentation = map_introduccion(chapter.get("INTRODUCCION"), resolver)
            chapter_id = self.repo.create_chapter(
                book_id, parent_id, name, None, _dump_blocks(presentation)
            )
            counters["chapters"] += 1
            self._import_recipes(chapter_id, as_list(chapter.get("RECETA")), resolver, counters)
            self._import_chapters(book_id, chapter_id, chapter.get("CAPITULO"), resolver, counters)

    def _import_recipes(self, chapter_id, recipes, resolver, counters) -> None:
        for legacy in recipes:
            recipe = map_recipe(legacy, resolver)
            self.repo.create_recipe(
                chapter_id,
                recipe.title,
                recipe.image,
                _dump_blocks(recipe.introduction),
                recipe.ingredients.model_dump(),
                _dump_blocks(recipe.preparation),
                recipe.note,
            )
            counters["recipes"] += 1


def validate_on_collision(value: str) -> str:
    if value not in ("replace", "keep_both"):
        raise ApiError("validation_error")
    return value
