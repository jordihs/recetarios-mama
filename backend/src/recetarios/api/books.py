"""Books endpoints (US1)."""

from fastapi import APIRouter, Request
from pydantic import BaseModel

from recetarios.api.deps import library_service
from recetarios.models.entities import BookInput

router = APIRouter()


class OrderInput(BaseModel):
    ids: list[str]


@router.get("/books")
async def list_books(request: Request):
    return library_service(request).list_books()


@router.post("/books")
async def create_book(request: Request, data: BookInput):
    return library_service(request).create_book(data)


@router.put("/books/order")
async def reorder_books(request: Request, data: OrderInput):
    return library_service(request).reorder_books(data.ids)


@router.get("/books/{book_id}")
async def get_book(request: Request, book_id: str):
    return library_service(request).get_book(book_id)


@router.put("/books/{book_id}")
async def update_book(request: Request, book_id: str, data: BookInput):
    return library_service(request).update_book(book_id, data)


@router.delete("/books/{book_id}")
async def delete_book(request: Request, book_id: str):
    library_service(request).delete_book(book_id)
    return {"status": "deleted"}
