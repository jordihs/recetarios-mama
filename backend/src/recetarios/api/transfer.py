"""Transfer endpoints: legacy import (US5), library export/import (US8)."""

from pathlib import Path

from fastapi import APIRouter, Request
from pydantic import BaseModel

from recetarios.api.deps import library_service, repository
from recetarios.services.archive import ArchiveService
from recetarios.services.legacy_import.importer import LegacyImporter, validate_on_collision

router = APIRouter()


class InspectInput(BaseModel):
    path: str


class LegacyImportInput(BaseModel):
    path: str
    on_collision: str = "keep_both"


def _importer(request: Request) -> LegacyImporter:
    return LegacyImporter(
        repository(request), request.app.state.images, library_service(request)
    )


@router.post("/import/legacy/inspect")
async def inspect_legacy(request: Request, data: InspectInput):
    return _importer(request).inspect(data.path)


@router.post("/import/legacy")
async def import_legacy(request: Request, data: LegacyImportInput):
    validate_on_collision(data.on_collision)
    return _importer(request).run(data.path, data.on_collision)


class ExportInput(BaseModel):
    path: str


class LibraryImportInput(BaseModel):
    path: str
    confirm_replace: bool = False


def _archive(request: Request) -> ArchiveService:
    return ArchiveService(
        request.app.state.db, repository(request), request.app.state.images
    )


@router.post("/library/export")
async def export_library(request: Request, data: ExportInput):
    return _archive(request).export(Path(data.path))


@router.post("/library/import")
async def import_library(request: Request, data: LibraryImportInput):
    return _archive(request).import_replace(Path(data.path), data.confirm_replace)
