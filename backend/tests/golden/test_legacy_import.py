"""US5 golden tests: import the three real legacy books from legacy/ (SC-002).

Expected counts are derived from the source documents with an independent
normalization (single-or-array shapes), then compared against what the API
exposes after import — 100% of chapters and recipes must survive.
"""

import json

import pytest
from tests.conftest import LEGACY_DIR

BOOKS = sorted(LEGACY_DIR.glob("*.json"))


def _as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def _source_counts(path):
    data = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]

    def walk(chapters):
        n_chapters = n_recipes = 0
        for chapter in _as_list(chapters):
            n_chapters += 1
            n_recipes += len(_as_list(chapter.get("RECETA")))
            sub_c, sub_r = walk(chapter.get("CAPITULO"))
            n_chapters += sub_c
            n_recipes += sub_r
        return n_chapters, n_recipes

    n_chapters, n_recipes = walk(data.get("CAPITULO"))
    n_recipes += len(_as_list(data.get("RECETA")))
    return {"title": data["TITULO"], "chapters": n_chapters, "recipes": n_recipes}


def _import(client, path, on_collision="keep_both"):
    response = client.post(
        "/import/legacy", json={"path": str(path), "on_collision": on_collision}
    )
    assert response.status_code == 200, response.text
    return response.json()


def _walk_api(client, book_id, parent=None):
    """Recursively count chapters/recipes through the public API."""
    chapters = client.get(
        f"/books/{book_id}/chapters", params={} if parent is None else {"parent": parent}
    ).json()
    n_chapters = n_recipes = 0
    for chapter in chapters:
        n_chapters += 1
        recipes = client.get(f"/chapters/{chapter['id']}/recipes").json()
        n_recipes += len(recipes)
        sub_c, sub_r = _walk_api(client, book_id, chapter["id"])
        n_chapters += sub_c
        n_recipes += sub_r
    return n_chapters, n_recipes


@pytest.mark.parametrize("path", BOOKS, ids=[p.stem[:20] for p in BOOKS])
def test_import_preserves_all_chapters_and_recipes(client, path):
    expected = _source_counts(path)
    result = _import(client, path)

    assert result["report"]["chapters"] == expected["chapters"]
    assert result["report"]["recipes"] == expected["recipes"]

    book = client.get(f"/books/{result['book_id']}").json()
    assert book["title"] == expected["title"]

    api_chapters, api_recipes = _walk_api(client, result["book_id"])
    assert api_chapters == expected["chapters"]
    assert api_recipes == expected["recipes"]


def test_nested_chapters_preserved(client):
    # 'b Las setas como ingrediente principal' contains nested chapters.
    path = next(p for p in BOOKS if p.name.startswith("b Las setas"))
    result = _import(client, path)
    top = client.get(f"/books/{result['book_id']}/chapters").json()
    nested_parents = [c for c in top if c["has_subchapters"]]
    assert nested_parents, "expected at least one top-level chapter with subchapters"
    sub = client.get(
        f"/books/{result['book_id']}/chapters", params={"parent": nested_parents[0]["id"]}
    ).json()
    assert sub, "subchapters must be reachable through the API"


def test_ingredient_groups_servings_and_notes_preserved(client):
    path = next(p for p in BOOKS if p.name == "recetas_de_mama.json")
    data = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]

    # Find a source recipe carrying 'personas' and grab its essentials.
    def find_recipe(chapters):
        for chapter in _as_list(chapters):
            for recipe in _as_list(chapter.get("RECETA")):
                ingredientes = recipe.get("INGREDIENTES") or {}
                personas = (ingredientes.get("@attributes") or {}).get("personas")
                if personas:
                    return recipe, personas
            found = find_recipe(chapter.get("CAPITULO"))
            if found:
                return found
        return None

    source_recipe, personas = find_recipe(data.get("CAPITULO"))
    result = _import(client, path)

    # Locate the imported recipe by title and compare.
    def find_imported(book_id, parent=None):
        for chapter in client.get(
            f"/books/{book_id}/chapters", params={} if parent is None else {"parent": parent}
        ).json():
            for summary in client.get(f"/chapters/{chapter['id']}/recipes").json():
                if summary["title"] == source_recipe["TITULO"].strip():
                    return client.get(f"/recipes/{summary['id']}").json()
            found = find_imported(book_id, chapter["id"])
            if found:
                return found
        return None

    imported = find_imported(result["book_id"])
    assert imported is not None
    assert imported["ingredients"]["servings"] == personas
    source_groups = _as_list(source_recipe["INGREDIENTES"]["GRUPO"])
    assert len(imported["ingredients"]["groups"]) == len(source_groups)
    if source_recipe.get("NOTA"):
        assert imported["note"]


def test_tables_preserved_in_presentations(client):
    path = next(p for p in BOOKS if p.name == "recetas_de_mama.json")
    data = json.loads(path.read_text(encoding="utf-8"))

    def count_tables(obj):
        if isinstance(obj, dict):
            n = len(_as_list(obj.get("TABLA"))) if "TABLA" in obj else 0
            return n + sum(count_tables(v) for k, v in obj.items() if k != "TABLA")
        if isinstance(obj, list):
            return sum(count_tables(i) for i in obj)
        return 0

    expected_tables = count_tables(data)
    result = _import(client, path)

    def count_table_blocks(blocks):
        return sum(1 for b in blocks if b.get("type") == "table")

    total = count_table_blocks(client.get(f"/books/{result['book_id']}").json()["presentation"])

    def walk(book_id, parent=None):
        nonlocal total
        for chapter in client.get(
            f"/books/{book_id}/chapters", params={} if parent is None else {"parent": parent}
        ).json():
            detail = client.get(f"/chapters/{chapter['id']}").json()
            total += count_table_blocks(detail["presentation"])
            walk(book_id, chapter["id"])

    walk(result["book_id"])
    assert total == expected_tables


def test_images_imported_and_resolvable(client):
    path = next(p for p in BOOKS if p.name == "recetas_de_mama.json")
    result = _import(client, path)
    report = result["report"]
    assert report["images_imported"] > 0

    # Every recipe image surviving import must be servable.
    checked = 0
    for chapter in client.get(f"/books/{result['book_id']}/chapters").json():
        for summary in client.get(f"/chapters/{chapter['id']}/recipes").json():
            if summary["image"]:
                assert client.get(f"/images/{summary['image']}").status_code == 200
                checked += 1
    assert checked > 0


def test_collision_inspect_and_replace(client):
    path = BOOKS[-1]
    _import(client, path)

    inspect = client.post("/import/legacy/inspect", json={"path": str(path)}).json()
    assert inspect["collision"] is True
    assert inspect["book_title"]

    # replace keeps a single copy
    _import(client, path, on_collision="replace")
    titles = [b["title"] for b in client.get("/books").json()]
    assert titles.count(inspect["book_title"]) == 1

    # keep_both adds a second copy
    _import(client, path, on_collision="keep_both")
    titles = [b["title"] for b in client.get("/books").json()]
    assert titles.count(inspect["book_title"]) == 2


def test_missing_file_reports_clear_error(client):
    response = client.post(
        "/import/legacy", json={"path": str(LEGACY_DIR / "nope.json"), "on_collision": "keep_both"}
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "legacy_file_not_found"
