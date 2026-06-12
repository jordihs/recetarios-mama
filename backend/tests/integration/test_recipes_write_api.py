"""Recipe create/update/delete with validation (markdown payloads)."""

import io

import pytest
from PIL import Image


@pytest.fixture()
def chapter_id(client):
    book = client.post("/books", json={"title": "Libro"}).json()
    chapter = client.post(
        f"/books/{book['id']}/chapters", json={"title": "Capítulo"}
    ).json()
    return chapter["id"]


def _upload_image(client) -> str:
    buf = io.BytesIO()
    Image.new("RGB", (4, 4), "green").save(buf, format="PNG")
    response = client.post(
        "/images", files={"file": ("img.png", buf.getvalue(), "image/png")}
    )
    return response.json()["hash"]


def _recipe_body(**overrides):
    body = {
        "title": "Tortilla",
        "introduction": "",
        "ingredients": {"servings": None, "groups": [{"title": None, "items": ["Huevos"]}]},
        "preparation": "Freír.",
        "note": None,
    }
    body.update(overrides)
    return body


def test_create_recipe(client, chapter_id):
    response = client.post(f"/chapters/{chapter_id}/recipes", json=_recipe_body())
    assert response.status_code == 200, response.text
    recipe = response.json()
    assert recipe["title"] == "Tortilla"
    assert recipe["chapter_id"] == chapter_id

    listed = client.get(f"/chapters/{chapter_id}/recipes").json()
    assert [r["title"] for r in listed] == ["Tortilla"]


def test_atomic_update(client, chapter_id):
    recipe = client.post(f"/chapters/{chapter_id}/recipes", json=_recipe_body()).json()
    response = client.put(
        f"/recipes/{recipe['id']}",
        json=_recipe_body(
            title="Tortilla de patatas",
            ingredients={
                "servings": "6",
                "groups": [{"title": None, "items": ["Huevos", "Patatas"]}],
            },
        ),
    )
    assert response.status_code == 200
    updated = client.get(f"/recipes/{recipe['id']}").json()
    assert updated["title"] == "Tortilla de patatas"
    assert updated["ingredients"]["servings"] == "6"
    assert updated["ingredients"]["groups"][0]["items"] == ["Huevos", "Patatas"]


def test_create_with_valid_image(client, chapter_id):
    image = _upload_image(client)
    body = _recipe_body(
        image=image,
        introduction=f"![Foto](image://{image})",
    )
    response = client.post(f"/chapters/{chapter_id}/recipes", json=body)
    assert response.status_code == 200
    assert response.json()["image"] == image
    assert response.json()["introduction"] == f"![Foto](image://{image})"


def test_unknown_image_ref_rejected(client, chapter_id):
    body = _recipe_body(introduction=f"![x](image://{'0' * 64})")
    response = client.post(f"/chapters/{chapter_id}/recipes", json=body)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_image_ref"


def test_non_string_content_rejected(client, chapter_id):
    body = _recipe_body(preparation=[{"type": "paragraph", "spans": []}])
    response = client.post(f"/chapters/{chapter_id}/recipes", json=body)
    assert response.status_code == 422


def test_oversized_document_rejected(client, chapter_id):
    body = _recipe_body(preparation="x" * (1024 * 1024 + 1))
    response = client.post(f"/chapters/{chapter_id}/recipes", json=body)
    assert response.status_code in (400, 422)


def test_empty_title_rejected(client, chapter_id):
    response = client.post(f"/chapters/{chapter_id}/recipes", json=_recipe_body(title="  "))
    assert response.status_code in (400, 422)


def test_delete_recipe(client, chapter_id):
    recipe = client.post(f"/chapters/{chapter_id}/recipes", json=_recipe_body()).json()
    response = client.delete(f"/recipes/{recipe['id']}")
    assert response.status_code == 200
    assert client.get(f"/recipes/{recipe['id']}").status_code == 404
    assert client.get(f"/chapters/{chapter_id}/recipes").json() == []


def test_create_in_missing_chapter_404(client):
    response = client.post("/chapters/nope/recipes", json=_recipe_body())
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "chapter_not_found"
