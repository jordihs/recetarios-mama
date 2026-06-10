"""US6: whole-book PDF — cover, index, chapter intro pages, page per recipe."""

import io
import time

import pytest
from PIL import Image
from pypdf import PdfReader


@pytest.fixture()
def library(client, tmp_path):
    """Book with two chapters (one nested), three recipes, and an image."""
    buf = io.BytesIO()
    Image.new("RGB", (40, 30), "orange").save(buf, format="PNG")
    image = client.post(
        "/images", files={"file": ("foto.png", buf.getvalue(), "image/png")}
    ).json()["hash"]

    book = client.post(
        "/books",
        json={
            "title": "Recetas de prueba",
            "cover_image": image,
            "presentation": [
                {"type": "paragraph", "spans": [{"text": "Las recetas de la familia."}]}
            ],
        },
    ).json()
    chapter1 = client.post(
        f"/books/{book['id']}/chapters",
        json={
            "title": "Entrantes",
            "presentation": [
                {"type": "paragraph", "spans": [{"text": "Para abrir el apetito."}]}
            ],
        },
    ).json()
    sub = client.post(
        f"/books/{book['id']}/chapters",
        json={"title": "Sopas frías", "parent_chapter_id": chapter1["id"]},
    ).json()

    def recipe(chapter, title, with_image=False):
        client.post(
            f"/chapters/{chapter}/recipes",
            json={
                "title": title,
                "image": image if with_image else None,
                "introduction": [
                    {"type": "paragraph", "spans": [{"text": f"Introducción de {title}."}]}
                ],
                "ingredients": {
                    "servings": "4",
                    "groups": [{"title": None, "items": ["Ingrediente uno", "Dos"]}],
                },
                "preparation": [
                    {"type": "paragraph", "spans": [{"text": f"Preparación de {title}."}]}
                ],
                "note": None,
            },
        )

    recipe(chapter1["id"], "Ensaladilla", with_image=True)
    recipe(sub["id"], "Gazpacho andaluz")
    recipe(sub["id"], "Salmorejo cordobés")
    return {"book_id": book["id"], "output_dir": str(tmp_path)}


def _wait_for_job(client, job_id, timeout=30.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        job = client.get(f"/pdf/jobs/{job_id}").json()
        if job["status"] != "running":
            return job
        time.sleep(0.1)
    raise AssertionError("PDF job did not finish in time")


def test_book_pdf_structure(client, library):
    response = client.post(
        f"/pdf/book/{library['book_id']}", json={"output_dir": library["output_dir"]}
    )
    assert response.status_code == 200
    job = _wait_for_job(client, response.json()["job_id"])
    assert job["status"] == "done", job
    path = job["path"]

    reader = PdfReader(path)
    pages = [page.extract_text() or "" for page in reader.pages]
    # Cover + index + 2 chapter pages + 3 recipes ⇒ at least 7 pages.
    assert len(pages) >= 7

    # Cover holds the book title.
    assert "Recetas de prueba" in pages[0]
    # An index page lists chapters and recipes (FR-029).
    index_pages = [p for p in pages if "Índice" in p]
    assert index_pages
    assert any("Gazpacho andaluz" in p for p in index_pages)
    # Every recipe begins at the top of its own page (FR-030).
    for title in ("Ensaladilla", "Gazpacho andaluz", "Salmorejo cordobés"):
        starts = [p for p in pages if p.strip().startswith(title)]
        assert starts, f"recipe '{title}' must start a page"
    # Spanish characters survive (SC-008).
    assert any("Introducción" in p for p in pages)


def test_book_pdf_missing_book_404(client, tmp_path):
    response = client.post("/pdf/book/nope", json={"output_dir": str(tmp_path)})
    assert response.status_code == 404


def test_book_pdf_invalid_output_dir(client, library):
    response = client.post(
        f"/pdf/book/{library['book_id']}",
        json={"output_dir": "Z:\\no\\existe\\esta\\carpeta"},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "output_dir_invalid"
