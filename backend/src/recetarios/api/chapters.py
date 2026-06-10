"""Chapters endpoints (US2): nested chapter CRUD and sibling reordering."""

from fastapi import APIRouter, Request
from pydantic import BaseModel

from recetarios.api.deps import library_service
from recetarios.models.entities import ChapterInput

router = APIRouter()


class ChapterOrderInput(BaseModel):
    book_id: str
    parent_chapter_id: str | None = None
    ids: list[str]


@router.get("/books/{book_id}/chapters")
async def list_chapters(request: Request, book_id: str, parent: str | None = None):
    return library_service(request).list_chapters(book_id, parent)


@router.post("/books/{book_id}/chapters")
async def create_chapter(request: Request, book_id: str, data: ChapterInput):
    return library_service(request).create_chapter(book_id, data)


@router.put("/chapters/order")
async def reorder_chapters(request: Request, data: ChapterOrderInput):
    return library_service(request).reorder_chapters(
        data.book_id, data.parent_chapter_id, data.ids
    )


@router.get("/chapters/{chapter_id}")
async def get_chapter(request: Request, chapter_id: str):
    return library_service(request).get_chapter(chapter_id)


@router.put("/chapters/{chapter_id}")
async def update_chapter(request: Request, chapter_id: str, data: ChapterInput):
    return library_service(request).update_chapter(chapter_id, data)


@router.delete("/chapters/{chapter_id}")
async def delete_chapter(request: Request, chapter_id: str):
    library_service(request).delete_chapter(chapter_id)
    return {"status": "deleted"}
