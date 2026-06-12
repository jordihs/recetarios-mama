"""US3 golden tests: imageless books/chapters inherit the first subtree image.

Legacy books and chapters never carry their own image, so after import every
one of them with at least one `image://` reference (or recipe image) in its
subtree must end up with exactly the *first* image of a depth-first,
document-order walk: own content → recipes (cover, then content) →
subchapters (FR-016..019). Recipes never receive fallbacks.
"""

import json
import re

import pytest
from tests.conftest import LEGACY_DIR

BOOKS = sorted(LEGACY_DIR.glob("*.json"))

_IMAGE_REF = re.compile(r"image://([0-9a-fA-F]{64})")


def _ordered_refs(markdown: str) -> list[str]:
    return [m.lower() for m in _IMAGE_REF.findall(markdown or "")]


def _import(client, path):
    response = client.post(
        "/import/legacy", json={"path": str(path), "on_collision": "keep_both"}
    )
    assert response.status_code == 200, response.text
    return response.json()


def _chapter_first_subtree_image(client, book_id, chapter):
    """First image of the imported chapter subtree, in document order."""
    detail = client.get(f"/chapters/{chapter['id']}").json()
    own = _ordered_refs(detail["presentation"])
    if own:
        return own[0]
    for summary in client.get(f"/chapters/{chapter['id']}/recipes").json():
        recipe = client.get(f"/recipes/{summary['id']}").json()
        if recipe["image"]:
            return recipe["image"]
        content = _ordered_refs(recipe["introduction"]) + _ordered_refs(
            recipe["preparation"]
        )
        if content:
            return content[0]
    for sub in client.get(
        f"/books/{book_id}/chapters", params={"parent": chapter["id"]}
    ).json():
        found = _chapter_first_subtree_image(client, book_id, sub)
        if found:
            return found
    return None


def _all_chapters(client, book_id, parent=None):
    chapters = client.get(
        f"/books/{book_id}/chapters", params={} if parent is None else {"parent": parent}
    ).json()
    result = []
    for chapter in chapters:
        result.append(chapter)
        result.extend(_all_chapters(client, book_id, chapter["id"]))
    return result


@pytest.mark.parametrize("path", BOOKS, ids=[p.stem[:20] for p in BOOKS])
def test_books_and_chapters_inherit_first_subtree_image(client, path):
    result = _import(client, path)
    book_id = result["book_id"]

    checked = 0
    for chapter in _all_chapters(client, book_id):
        expected = _chapter_first_subtree_image(client, book_id, chapter)
        detail = client.get(f"/chapters/{chapter['id']}").json()
        assert detail["cover_image"] == expected, (
            f"chapter '{detail['title']}': cover {detail['cover_image']}"
            f" != first subtree image {expected}"
        )
        if expected:
            checked += 1
    assert checked > 0, "sample book should have image-bearing chapters"

    # The book itself: own presentation first, then its chapters in order.
    book = client.get(f"/books/{book_id}").json()
    own = _ordered_refs(book["presentation"])
    expected = own[0] if own else None
    if expected is None:
        for chapter in client.get(f"/books/{book_id}/chapters").json():
            expected = _chapter_first_subtree_image(client, book_id, chapter)
            if expected:
                break
    assert book["cover_image"] == expected


def test_recipes_never_receive_fallbacks(client):
    """A source recipe without its own image stays imageless after import."""
    for path in BOOKS:
        source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]

        def find_imageless(chapters):
            chapters = chapters if isinstance(chapters, list) else [chapters] if chapters else []
            for chapter in chapters:
                recipes = chapter.get("RECETA")
                recipes = recipes if isinstance(recipes, list) else [recipes] if recipes else []
                for recipe in recipes:
                    if not (recipe.get("@attributes") or {}).get("imagen"):
                        return recipe["TITULO"].strip()
                found = find_imageless(chapter.get("CAPITULO"))
                if found:
                    return found
            return None

        title = find_imageless(source.get("CAPITULO"))
        if title is None:
            continue
        result = _import(client, path)

        def find_imported(book_id, parent=None, title=title):
            for chapter in client.get(
                f"/books/{book_id}/chapters",
                params={} if parent is None else {"parent": parent},
            ).json():
                for summary in client.get(f"/chapters/{chapter['id']}/recipes").json():
                    if summary["title"] == title:
                        return summary
                found = find_imported(book_id, chapter["id"])
                if found:
                    return found
            return None

        imported = find_imported(result["book_id"])
        assert imported is not None
        assert imported["image"] is None
        return
    pytest.fail("no imageless recipe found in the sample books")


def test_no_images_anywhere_imports_cleanly_imageless(client, tmp_path):
    document = {
        "RECETARIO": {
            "TITULO": "Sin imágenes",
            "INTRODUCCION": {"CONTENIDO": [{"tipo": "PARRAFO", "texto": "Texto."}]},
            "CAPITULO": [
                {
                    "@attributes": {"nombre": "Capítulo llano"},
                    "INTRODUCCION": {"CONTENIDO": [{"tipo": "PARRAFO", "texto": "Más."}]},
                    "RECETA": [
                        {
                            "TITULO": "Receta sobria",
                            "INGREDIENTES": {"GRUPO": {"INGREDIENTE": "Agua"}},
                            "PREPARACION": "Hervir.",
                        }
                    ],
                }
            ],
        }
    }
    path = tmp_path / "sin_imagenes.json"
    path.write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")

    result = _import(client, path)
    book = client.get(f"/books/{result['book_id']}").json()
    assert book["cover_image"] is None
    for chapter in _all_chapters(client, result["book_id"]):
        assert client.get(f"/chapters/{chapter['id']}").json()["cover_image"] is None
