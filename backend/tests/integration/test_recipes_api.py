"""Recipe list summaries and full detail (read endpoints + reorder)."""

import pytest

from recetarios.storage.db import Database
from recetarios.storage.repository import Repository

RECIPE_BODY = {
    "introduction": "Una receta de la abuela.",
    "ingredients": {
        "servings": "4",
        "groups": [
            {"title": None, "items": ["2 huevos", "Sal"]},
            {"title": "Para el aliño", "items": ["Aceite de oliva"]},
        ],
    },
    "preparation": "Batir y freír.",
    "note": "Mejor en sartén de hierro.",
}


@pytest.fixture()
def seed(client, data_dir):
    """Direct-repository seeding for read-only endpoint tests."""
    db = Database(data_dir)
    repo = Repository(db)
    yield repo
    db.close()


@pytest.fixture()
def chapter_id(client):
    book = client.post("/books", json={"title": "Libro"}).json()
    chapter = client.post(
        f"/books/{book['id']}/chapters", json={"title": "Capítulo"}
    ).json()
    return chapter["id"]


def _seed_recipe(repo, chapter_id, title="Tortilla", **overrides):
    body = {**RECIPE_BODY, **overrides}
    return repo.create_recipe(
        chapter_id,
        title,
        body.get("image"),
        body["introduction"],
        body["ingredients"],
        body["preparation"],
        body.get("note"),
    )


def test_list_recipes_summaries(client, seed, chapter_id):
    _seed_recipe(seed, chapter_id, "Tortilla")
    _seed_recipe(seed, chapter_id, "Gazpacho")

    response = client.get(f"/chapters/{chapter_id}/recipes")
    assert response.status_code == 200
    recipes = response.json()
    assert [r["title"] for r in recipes] == ["Tortilla", "Gazpacho"]
    assert recipes[0]["description"] == "Una receta de la abuela."
    assert "ingredients" not in recipes[0]  # summaries stay light


def test_description_derived_from_first_markdown_paragraph(client, seed, chapter_id):
    _seed_recipe(
        seed,
        chapter_id,
        "Sopa",
        introduction="## Historia\n\nLa hacía *siempre* en otoño.\n",
    )
    recipes = client.get(f"/chapters/{chapter_id}/recipes").json()
    assert recipes[0]["description"] == "La hacía siempre en otoño."


def test_recipe_detail_full_payload(client, seed, chapter_id):
    recipe_id = _seed_recipe(seed, chapter_id)
    response = client.get(f"/recipes/{recipe_id}")
    assert response.status_code == 200
    detail = response.json()
    assert detail["title"] == "Tortilla"
    assert detail["chapter_id"] == chapter_id
    assert detail["ingredients"]["servings"] == "4"
    assert detail["ingredients"]["groups"][1]["title"] == "Para el aliño"
    assert detail["preparation"] == "Batir y freír."
    assert detail["introduction"] == "Una receta de la abuela."
    assert detail["note"] == "Mejor en sartén de hierro."


def test_recipe_count_in_chapter_summary(client, seed, chapter_id):
    _seed_recipe(seed, chapter_id)
    book_id = client.get(f"/chapters/{chapter_id}").json()["book_id"]
    chapters = client.get(f"/books/{book_id}/chapters").json()
    assert chapters[0]["recipe_count"] == 1


def test_reorder_recipes(client, seed, chapter_id):
    a = _seed_recipe(seed, chapter_id, "A")
    b = _seed_recipe(seed, chapter_id, "B")
    response = client.put(
        "/recipes/order", json={"chapter_id": chapter_id, "ids": [b, a]}
    )
    assert response.status_code == 200
    titles = [r["title"] for r in client.get(f"/chapters/{chapter_id}/recipes").json()]
    assert titles == ["B", "A"]


def test_reorder_rejects_partial(client, seed, chapter_id):
    a = _seed_recipe(seed, chapter_id, "A")
    _seed_recipe(seed, chapter_id, "B")
    response = client.put("/recipes/order", json={"chapter_id": chapter_id, "ids": [a]})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_order"


def test_missing_recipe_404(client):
    response = client.get("/recipes/nope")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "recipe_not_found"
