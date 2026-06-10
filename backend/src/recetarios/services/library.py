"""Domain services for books/chapters/recipes. Books for US1."""

import json
from sqlite3 import Row

from pydantic import TypeAdapter

from recetarios.api.errors import ApiError, NotFoundError
from recetarios.models.blocks import (
    ContentBlock,
    first_paragraph_text,
    referenced_image_hashes,
)
from recetarios.models.entities import BookInput, ChapterInput, RecipeInput
from recetarios.storage.images import ImageStore
from recetarios.storage.repository import Repository

_blocks_adapter = TypeAdapter(list[ContentBlock])


def parse_blocks(raw: str) -> list[ContentBlock]:
    return _blocks_adapter.validate_python(json.loads(raw))


class LibraryService:
    def __init__(self, repo: Repository, images: ImageStore):
        self.repo = repo
        self.images = images

    # ------------------------------------------------------------------ books

    def list_books(self) -> list[dict]:
        return [self._book_summary(row) for row in self.repo.list_books()]

    def get_book(self, book_id: str) -> dict:
        row = self.repo.get_book(book_id)
        if row is None:
            raise NotFoundError("book_not_found")
        return self._book_detail(row)

    def create_book(self, data: BookInput) -> dict:
        self._check_image_refs(data.cover_image, data.presentation)
        book_id = self.repo.create_book(
            data.title, data.cover_image, _dump_blocks(data.presentation)
        )
        return self.get_book(book_id)

    def update_book(self, book_id: str, data: BookInput) -> dict:
        if self.repo.get_book(book_id) is None:
            raise NotFoundError("book_not_found")
        self._check_image_refs(data.cover_image, data.presentation)
        self.repo.update_book(
            book_id, data.title, data.cover_image, _dump_blocks(data.presentation)
        )
        return self.get_book(book_id)

    def delete_book(self, book_id: str) -> None:
        if self.repo.get_book(book_id) is None:
            raise NotFoundError("book_not_found")
        self.repo.delete_book(book_id)

    def reorder_books(self, ids: list[str]) -> list[dict]:
        if not self.repo.reorder_books(ids):
            raise ApiError("invalid_order")
        return self.list_books()

    # --------------------------------------------------------------- chapters

    def list_chapters(self, book_id: str, parent_chapter_id: str | None) -> list[dict]:
        if self.repo.get_book(book_id) is None:
            raise NotFoundError("book_not_found")
        return [
            self._chapter_summary(row)
            for row in self.repo.list_chapters(book_id, parent_chapter_id)
        ]

    def get_chapter(self, chapter_id: str) -> dict:
        row = self.repo.get_chapter(chapter_id)
        if row is None:
            raise NotFoundError("chapter_not_found")
        return self._chapter_detail(row)

    def create_chapter(self, book_id: str, data: ChapterInput) -> dict:
        if self.repo.get_book(book_id) is None:
            raise NotFoundError("book_not_found")
        self._validate_parent(book_id, data.parent_chapter_id, chapter_id=None)
        self._check_image_refs(data.cover_image, data.presentation)
        chapter_id = self.repo.create_chapter(
            book_id,
            data.parent_chapter_id,
            data.title,
            data.cover_image,
            _dump_blocks(data.presentation),
        )
        return self.get_chapter(chapter_id)

    def update_chapter(self, chapter_id: str, data: ChapterInput) -> dict:
        row = self.repo.get_chapter(chapter_id)
        if row is None:
            raise NotFoundError("chapter_not_found")
        self._validate_parent(row["book_id"], data.parent_chapter_id, chapter_id=chapter_id)
        self._check_image_refs(data.cover_image, data.presentation)
        self.repo.update_chapter(
            chapter_id,
            data.parent_chapter_id,
            data.title,
            data.cover_image,
            _dump_blocks(data.presentation),
        )
        return self.get_chapter(chapter_id)

    def delete_chapter(self, chapter_id: str) -> None:
        if self.repo.get_chapter(chapter_id) is None:
            raise NotFoundError("chapter_not_found")
        self.repo.delete_chapter(chapter_id)

    def reorder_chapters(
        self, book_id: str, parent_chapter_id: str | None, ids: list[str]
    ) -> list[dict]:
        if not self.repo.reorder_chapters(book_id, parent_chapter_id, ids):
            raise ApiError("invalid_order")
        return self.list_chapters(book_id, parent_chapter_id)

    def _validate_parent(
        self, book_id: str, parent_id: str | None, chapter_id: str | None
    ) -> None:
        if parent_id is None:
            return
        parent = self.repo.get_chapter(parent_id)
        if parent is None or parent["book_id"] != book_id:
            raise ApiError("invalid_parent_chapter")
        # Walk up from the new parent; finding the chapter itself means a cycle.
        current = parent
        while current is not None:
            if chapter_id is not None and current["id"] == chapter_id:
                raise ApiError("invalid_parent_chapter")
            parent_ref = current["parent_chapter_id"]
            current = self.repo.get_chapter(parent_ref) if parent_ref else None

    def _chapter_summary(self, row: Row) -> dict:
        return {
            "id": row["id"],
            "title": row["title"],
            "cover_image": row["cover_image"],
            "description": first_paragraph_text(parse_blocks(row["presentation"])),
            "has_subchapters": self.repo.chapter_has_subchapters(row["id"]),
            "recipe_count": self.repo.chapter_recipe_count(row["id"]),
        }

    def _chapter_detail(self, row: Row) -> dict:
        return {
            "id": row["id"],
            "book_id": row["book_id"],
            "parent_chapter_id": row["parent_chapter_id"],
            "title": row["title"],
            "cover_image": row["cover_image"],
            "presentation": json.loads(row["presentation"]),
            "position": row["position"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    # ---------------------------------------------------------------- recipes

    def list_recipes(self, chapter_id: str) -> list[dict]:
        if self.repo.get_chapter(chapter_id) is None:
            raise NotFoundError("chapter_not_found")
        return [self._recipe_summary(row) for row in self.repo.list_recipes(chapter_id)]

    def get_recipe(self, recipe_id: str) -> dict:
        row = self.repo.get_recipe(recipe_id)
        if row is None:
            raise NotFoundError("recipe_not_found")
        return self._recipe_detail(row)

    def reorder_recipes(self, chapter_id: str, ids: list[str]) -> list[dict]:
        if not self.repo.reorder_recipes(chapter_id, ids):
            raise ApiError("invalid_order")
        return self.list_recipes(chapter_id)

    def create_recipe(self, chapter_id: str, data: RecipeInput) -> dict:
        if self.repo.get_chapter(chapter_id) is None:
            raise NotFoundError("chapter_not_found")
        self._check_recipe_images(data)
        recipe_id = self.repo.create_recipe(
            chapter_id,
            data.title,
            data.image,
            _dump_blocks(data.introduction),
            data.ingredients.model_dump(),
            _dump_blocks(data.preparation),
            data.note,
        )
        return self.get_recipe(recipe_id)

    def update_recipe(self, recipe_id: str, data: RecipeInput) -> dict:
        if self.repo.get_recipe(recipe_id) is None:
            raise NotFoundError("recipe_not_found")
        self._check_recipe_images(data)
        self.repo.update_recipe(
            recipe_id,
            data.title,
            data.image,
            _dump_blocks(data.introduction),
            data.ingredients.model_dump(),
            _dump_blocks(data.preparation),
            data.note,
        )
        return self.get_recipe(recipe_id)

    def delete_recipe(self, recipe_id: str) -> None:
        if self.repo.get_recipe(recipe_id) is None:
            raise NotFoundError("recipe_not_found")
        self.repo.delete_recipe(recipe_id)

    def _check_recipe_images(self, data: RecipeInput) -> None:
        for ref in data.referenced_images():
            if not self.images.exists(ref):
                raise ApiError("invalid_image_ref")

    def _recipe_summary(self, row: Row) -> dict:
        return {
            "id": row["id"],
            "title": row["title"],
            "image": row["image"],
            "description": first_paragraph_text(parse_blocks(row["introduction"])),
        }

    def _recipe_detail(self, row: Row) -> dict:
        return {
            "id": row["id"],
            "chapter_id": row["chapter_id"],
            "title": row["title"],
            "image": row["image"],
            "introduction": json.loads(row["introduction"]),
            "ingredients": json.loads(row["ingredients"]),
            "preparation": json.loads(row["preparation"]),
            "note": row["note"],
            "position": row["position"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    # ---------------------------------------------------------------- helpers

    def _check_image_refs(self, cover: str | None, blocks: list[ContentBlock]) -> None:
        refs = referenced_image_hashes(blocks)
        if cover:
            refs.add(cover)
        for ref in refs:
            if not self.images.exists(ref):
                raise ApiError("invalid_image_ref")

    def _book_summary(self, row: Row) -> dict:
        return {
            "id": row["id"],
            "title": row["title"],
            "cover_image": row["cover_image"],
            "description": first_paragraph_text(parse_blocks(row["presentation"])),
        }

    def _book_detail(self, row: Row) -> dict:
        return {
            "id": row["id"],
            "title": row["title"],
            "cover_image": row["cover_image"],
            "presentation": json.loads(row["presentation"]),
            "position": row["position"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }


def _dump_blocks(blocks: list[ContentBlock]) -> list[dict]:
    return [block.model_dump() for block in blocks]
