"""Settings endpoints (FR-035)."""

from fastapi import APIRouter, Request

from recetarios.services.settings import SettingsService

router = APIRouter()


@router.get("/settings")
async def get_settings(request: Request):
    return SettingsService(request.app.state.db).get_all()


@router.put("/settings")
async def update_settings(request: Request):
    values = await request.json()
    return SettingsService(request.app.state.db).update(values)
