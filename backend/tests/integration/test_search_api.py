"""US9: accent/case-insensitive full-text search with breadcrumbs (FR-036..038)."""

import pytest


@pytest.fixture()
def library(client):
    book = client.post("/books", json={"title": "Setas"}).json()
    chapter = client.post(f"/books/{book['id']}/chapters", json={"title": "Guisos"}).json()
    nested = client.post(
        f"/books/{book['id']}/chapters",
        json={"title": "De temporada", "parent_chapter_id": chapter["id"]},
    ).json()

    def recipe(chapter_id, title, ingredient="Sal", preparation="Cocinar.", intro=None):
        return client.post(
            f"/chapters/{chapter_id}/recipes",
            json={
                "title": title,
                "introduction": []
                if intro is None
                else [{"type": "paragraph", "spans": [{"text": intro}]}],
                "ingredients": {
                    "servings": None,
                    "groups": [{"title": None, "items": [ingredient]}],
                },
                "preparation": [{"type": "paragraph", "spans": [{"text": preparation}]}],
                "note": None,
            },
        ).json()

    r1 = recipe(chapter["id"], "Guiso de champiñón", ingredient="500 g de champiñones")
    r2 = recipe(nested["id"], "Níscalos al ajillo", preparation="Saltear los níscalos.")
    r3 = recipe(nested["id"], "Sopa", intro="Una sopa de invierno con apio.")
    return {"book": book, "chapter": chapter, "nested": nested, "r1": r1, "r2": r2, "r3": r3}


def _search(client, q):
    response = client.get("/search", params={"q": q})
    assert response.status_code == 200
    return response.json()


def test_accent_and_case_insensitive_title_match(client, library):
    results = _search(client, "CHAMPINON")
    assert any(r["recipe_id"] == library["r1"]["id"] for r in results)


def test_matches_ingredients_preparation_and_introduction(client, library):
    assert any(r["recipe_id"] == library["r1"]["id"] for r in _search(client, "champinones"))
    assert any(r["recipe_id"] == library["r2"]["id"] for r in _search(client, "saltear"))
    assert any(r["recipe_id"] == library["r3"]["id"] for r in _search(client, "apio"))


def test_breadcrumb_reflects_nesting(client, library):
    results = _search(client, "niscalos")
    match = next(r for r in results if r["recipe_id"] == library["r2"]["id"])
    titles = [step["title"] for step in match["breadcrumb"]]
    assert titles == ["Setas", "Guisos", "De temporada"]


def test_index_stays_in_sync_with_updates(client, library):
    recipe = library["r3"]
    body = {
        "title": "Sopa de calabaza",
        "introduction": [],
        "ingredients": {"servings": None, "groups": [{"title": None, "items": ["Calabaza"]}]},
        "preparation": [{"type": "paragraph", "spans": [{"text": "Triturar."}]}],
        "note": None,
    }
    client.put(f"/recipes/{recipe['id']}", json=body)

    assert not _search(client, "apio")  # old text gone
    assert any(r["recipe_id"] == recipe["id"] for r in _search(client, "calabaza"))

    client.delete(f"/recipes/{recipe['id']}")
    assert not _search(client, "calabaza")


def test_no_results_is_empty_list(client, library):
    assert _search(client, "zzzznoexiste") == []
