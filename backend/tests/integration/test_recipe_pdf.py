"""US7: single-recipe PDF honoring include/skip flags (FR-031..033)."""

import io

import pytest
from PIL import Image
from pypdf import PdfReader


@pytest.fixture()
def recipe_id(client):
    buf = io.BytesIO()
    Image.new("RGB", (30, 20), "purple").save(buf, format="PNG")
    image = client.post(
        "/images", files={"file": ("r.png", buf.getvalue(), "image/png")}
    ).json()["hash"]

    book = client.post("/books", json={"title": "Libro"}).json()
    chapter = client.post(f"/books/{book['id']}/chapters", json={"title": "Cap"}).json()
    recipe = client.post(
        f"/chapters/{chapter['id']}/recipes",
        json={
            "title": "Tortilla francesa",
            "image": image,
            "introduction": "TEXTO-DE-INTRODUCCION\n\n"
            "**Tiempos**\n\n| Paso | Minutos |\n| --- | --- |\n| Batir | 2 |\n",
            "ingredients": {"servings": "2", "groups": [{"title": None, "items": ["Huevos"]}]},
            "preparation": "Batir y **cuajar**.\n\n- Punto uno\n- Punto dos\n",
            "note": None,
        },
    ).json()
    return recipe["id"]


def _generate(client, recipe_id, tmp_path, include_introduction, include_images):
    response = client.post(
        f"/pdf/recipe/{recipe_id}",
        json={
            "include_introduction": include_introduction,
            "include_images": include_images,
            "output_dir": str(tmp_path),
        },
    )
    assert response.status_code == 200, response.text
    return response.json()["path"]


def _text_and_images(path):
    reader = PdfReader(path)
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    image_count = sum(len(page.images) for page in reader.pages)
    return text, image_count


def test_full_recipe_pdf(client, recipe_id, tmp_path):
    path = _generate(client, recipe_id, tmp_path, True, True)
    text, images = _text_and_images(path)
    assert "Tortilla francesa" in text
    assert "TEXTO-DE-INTRODUCCION" in text
    assert "Ingredientes" in text and "Preparación" in text
    assert images >= 1


def test_skip_introduction(client, recipe_id, tmp_path):
    path = _generate(client, recipe_id, tmp_path, False, True)
    text, _ = _text_and_images(path)
    assert "TEXTO-DE-INTRODUCCION" not in text
    assert "Ingredientes" in text


def test_skip_images(client, recipe_id, tmp_path):
    path = _generate(client, recipe_id, tmp_path, True, False)
    text, images = _text_and_images(path)
    assert "TEXTO-DE-INTRODUCCION" in text
    assert images == 0


def test_output_lands_in_requested_dir(client, recipe_id, tmp_path):
    path = _generate(client, recipe_id, tmp_path, True, True)
    assert str(tmp_path) in path


def test_invalid_output_dir(client, recipe_id):
    response = client.post(
        f"/pdf/recipe/{recipe_id}",
        json={
            "include_introduction": True,
            "include_images": True,
            "output_dir": "Z:\\no\\existe",
        },
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "output_dir_invalid"
