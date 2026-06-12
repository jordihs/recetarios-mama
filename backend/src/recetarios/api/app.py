"""FastAPI application factory."""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from recetarios.api.errors import ApiError
from recetarios.l10n.messages import msg
from recetarios.storage.db import Database
from recetarios.storage.images import ImageStore

API_VERSION = "0.1.0"


def create_app(data_dir: Path) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.db = Database(Path(data_dir))
        app.state.images = ImageStore(app.state.db)
        yield
        app.state.db.close()

    app = FastAPI(title="recetarios", version=API_VERSION, lifespan=lifespan)

    @app.exception_handler(ApiError)
    async def api_error_handler(_request: Request, exc: ApiError):
        return JSONResponse(
            status_code=exc.status,
            content={"error": {"code": exc.code, "message": exc.message}},
        )

    @app.exception_handler(RequestValidationError)
    async def validation_handler(_request: Request, _exc: RequestValidationError):
        return JSONResponse(
            status_code=422,
            content={"error": {"code": "validation_error", "message": msg("validation_error")}},
        )

    @app.get("/health")
    async def health():
        return {"status": "ok", "version": API_VERSION}

    _register_routers(app)
    return app


def _register_routers(app: FastAPI) -> None:
    from recetarios.api import books, chapters, images, pdf, recipes, search, settings, transfer

    app.include_router(images.router)
    app.include_router(books.router)
    app.include_router(chapters.router)
    app.include_router(recipes.router)
    app.include_router(transfer.router)
    app.include_router(pdf.router)
    app.include_router(settings.router)
    app.include_router(search.router)
