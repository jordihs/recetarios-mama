"""Library format status and reset flow (no-migration policy).

A v1 database is never read or written; the frontend checks /library/status
at startup and offers the reset, which recreates the database at schema v2.
The images directory is preserved: files are content-addressed, so a re-import
reuses them.
"""

from fastapi import APIRouter, Request
from pydantic import BaseModel

from recetarios.api.errors import ApiError
from recetarios.storage.db import Database
from recetarios.storage.images import ImageStore

router = APIRouter()


class ResetInput(BaseModel):
    confirm: bool = False


@router.get("/library/status")
async def library_status(request: Request):
    return {"format": request.app.state.db.format}


@router.post("/library/reset")
async def library_reset(request: Request, data: ResetInput):
    if not data.confirm:
        raise ApiError("reset_confirm_required")
    state = request.app.state
    data_dir = state.db.data_dir
    state.db.close()
    for suffix in ("", "-wal", "-shm"):
        path = data_dir / f"recetarios.db{suffix}"
        path.unlink(missing_ok=True)
    state.db = Database(data_dir)
    state.images = ImageStore(state.db)
    # Cached per-app singletons hold the old connection; rebuild lazily.
    for attr in ("repository", "library"):
        if hasattr(state, attr):
            delattr(state, attr)
    return {"format": state.db.format}
