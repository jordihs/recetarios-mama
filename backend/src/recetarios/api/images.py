"""Image ingest and serving endpoints."""

from fastapi import APIRouter, Request, UploadFile
from fastapi.responses import FileResponse

from recetarios.api.errors import ApiError, NotFoundError
from recetarios.storage.images import ImageStore, ImageStoreError

router = APIRouter()

_MEDIA_TYPES = {
    "jpg": "image/jpeg",
    "png": "image/png",
    "gif": "image/gif",
    "webp": "image/webp",
    "bmp": "image/bmp",
}


def _store(request: Request) -> ImageStore:
    return request.app.state.images


@router.post("/images")
async def upload_image(request: Request, file: UploadFile):
    data = await file.read()
    try:
        return _store(request).ingest(data)
    except ImageStoreError as exc:
        raise ApiError("invalid_image_data") from exc


@router.get("/images/{hash_}")
async def get_image(request: Request, hash_: str):
    path = _store(request).path_for(hash_)
    if path is None:
        raise NotFoundError("image_not_found")
    media_type = _MEDIA_TYPES.get(path.suffix.lstrip("."), "application/octet-stream")
    return FileResponse(
        path,
        media_type=media_type,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )
