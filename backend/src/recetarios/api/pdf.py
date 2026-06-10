"""PDF generation endpoints: book PDFs as polled jobs (US6),
single-recipe PDFs synchronously (US7)."""

import threading
import uuid

from fastapi import APIRouter, Request
from pydantic import BaseModel

from recetarios.api.deps import library_service
from recetarios.api.errors import NotFoundError
from recetarios.services.pdf.book_builder import BookPdfBuilder
from recetarios.services.pdf.recipe_builder import RecipePdfBuilder
from recetarios.services.settings import PDF_OUTPUT_DIR, SettingsService, validate_output_dir

router = APIRouter()

_jobs: dict[str, dict] = {}
_jobs_lock = threading.Lock()


class PdfRequest(BaseModel):
    output_dir: str | None = None


def _resolve_output_dir(request: Request, requested: str | None):
    settings = SettingsService(request.app.state.db)
    return validate_output_dir(requested or settings.get(PDF_OUTPUT_DIR))


@router.post("/pdf/book/{book_id}")
async def build_book_pdf(request: Request, book_id: str, data: PdfRequest):
    library = library_service(request)
    library.get_book(book_id)  # 404 before starting the job
    output_dir = _resolve_output_dir(request, data.output_dir)

    job_id = str(uuid.uuid4())
    with _jobs_lock:
        _jobs[job_id] = {"status": "running", "path": None, "error": None}

    builder = BookPdfBuilder(library, request.app.state.images)

    def run() -> None:
        try:
            path = builder.build(book_id, output_dir)
            with _jobs_lock:
                _jobs[job_id].update(status="done", path=str(path))
        except Exception as exc:  # surfaced through the job, not the API call
            with _jobs_lock:
                _jobs[job_id].update(status="error", error=str(exc))

    threading.Thread(target=run, daemon=True).start()
    return {"job_id": job_id}


class RecipePdfRequest(BaseModel):
    include_introduction: bool = True
    include_images: bool = True
    output_dir: str | None = None


@router.post("/pdf/recipe/{recipe_id}")
async def build_recipe_pdf(request: Request, recipe_id: str, data: RecipePdfRequest):
    library = library_service(request)
    library.get_recipe(recipe_id)  # 404 first
    output_dir = _resolve_output_dir(request, data.output_dir)
    builder = RecipePdfBuilder(library, request.app.state.images)
    path = builder.build(
        recipe_id, output_dir, data.include_introduction, data.include_images
    )
    return {"path": str(path)}


@router.get("/pdf/jobs/{job_id}")
async def get_pdf_job(job_id: str):
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            raise NotFoundError("pdf_job_not_found")
        return dict(job)
