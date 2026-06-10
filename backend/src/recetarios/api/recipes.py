"""Recipes endpoints: read + reorder (US3), create/update/delete (US4)."""

from fastapi import APIRouter, Request
from pydantic import BaseModel

from recetarios.api.deps import library_service
from recetarios.models.entities import RecipeInput

router = APIRouter()


class RecipeOrderInput(BaseModel):
    chapter_id: str
    ids: list[str]


@router.get("/chapters/{chapter_id}/recipes")
async def list_recipes(request: Request, chapter_id: str):
    return library_service(request).list_recipes(chapter_id)


@router.post("/chapters/{chapter_id}/recipes")
async def create_recipe(request: Request, chapter_id: str, data: RecipeInput):
    return library_service(request).create_recipe(chapter_id, data)


@router.put("/recipes/order")
async def reorder_recipes(request: Request, data: RecipeOrderInput):
    return library_service(request).reorder_recipes(data.chapter_id, data.ids)


@router.get("/recipes/{recipe_id}")
async def get_recipe(request: Request, recipe_id: str):
    return library_service(request).get_recipe(recipe_id)


@router.put("/recipes/{recipe_id}")
async def update_recipe(request: Request, recipe_id: str, data: RecipeInput):
    return library_service(request).update_recipe(recipe_id, data)


@router.delete("/recipes/{recipe_id}")
async def delete_recipe(request: Request, recipe_id: str):
    library_service(request).delete_recipe(recipe_id)
    return {"status": "deleted"}
