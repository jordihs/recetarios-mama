"""Full-text search endpoint (FR-036..038)."""

from fastapi import APIRouter, Request

from recetarios.api.deps import repository

router = APIRouter()


@router.get("/search")
async def search(request: Request, q: str = ""):
    repo = repository(request)
    results = []
    for row in repo.search(q):
        results.append(
            {
                "recipe_id": row["recipe_id"],
                "title": row["title"],
                "breadcrumb": _breadcrumb(repo, row["chapter_id"]),
                "snippet": row["snippet"],
            }
        )
    return results


def _breadcrumb(repo, chapter_id: str) -> list[dict]:
    """Book → chapter path → (recipe excluded; the result itself is the recipe)."""
    steps: list[dict] = []
    current = repo.get_chapter(chapter_id)
    while current is not None:
        steps.append({"type": "chapter", "id": current["id"], "title": current["title"]})
        parent = current["parent_chapter_id"]
        current = repo.get_chapter(parent) if parent else None
    if steps:
        book = repo.get_book(repo.get_chapter(chapter_id)["book_id"])
        if book is not None:
            steps.append({"type": "book", "id": book["id"], "title": book["title"]})
    steps.reverse()
    return steps
