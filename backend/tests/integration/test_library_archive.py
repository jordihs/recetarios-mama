"""US8: full library export/import round trip with replace semantics (SC-007)."""

import io

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from recetarios.api.app import create_app


@pytest.fixture()
def populated(client):
    buf = io.BytesIO()
    Image.new("RGB", (16, 16), "teal").save(buf, format="PNG")
    image = client.post(
        "/images", files={"file": ("i.png", buf.getvalue(), "image/png")}
    ).json()["hash"]

    book = client.post(
        "/books",
        json={
            "title": "Libro exportado",
            "cover_image": image,
            "presentation": [{"type": "paragraph", "spans": [{"text": "Descripción."}]}],
        },
    ).json()
    chapter = client.post(
        f"/books/{book['id']}/chapters", json={"title": "Capítulo uno"}
    ).json()
    sub = client.post(
        f"/books/{book['id']}/chapters",
        json={"title": "Anidado", "parent_chapter_id": chapter["id"]},
    ).json()
    client.post(
        f"/chapters/{sub['id']}/recipes",
        json={
            "title": "Receta anidada",
            "image": image,
            "introduction": [{"type": "paragraph", "spans": [{"text": "Intro."}]}],
            "ingredients": {"servings": "2", "groups": [{"title": "G", "items": ["x"]}]},
            "preparation": [{"type": "paragraph", "spans": [{"text": "Prep."}]}],
            "note": "nota",
        },
    )
    return {"image": image}


def _snapshot(client):
    """Full library content through the API, normalized for comparison."""

    def chapters(book_id, parent=None):
        result = []
        params = {} if parent is None else {"parent": parent}
        for c in client.get(f"/books/{book_id}/chapters", params=params).json():
            detail = client.get(f"/chapters/{c['id']}").json()
            recipes = [
                client.get(f"/recipes/{r['id']}").json()
                for r in client.get(f"/chapters/{c['id']}/recipes").json()
            ]
            result.append(
                {
                    "title": detail["title"],
                    "presentation": detail["presentation"],
                    "recipes": [
                        {k: r[k] for k in ("title", "image", "introduction", "ingredients",
                                           "preparation", "note")}
                        for r in recipes
                    ],
                    "children": chapters(book_id, c["id"]),
                }
            )
        return result

    snapshot = []
    for b in client.get("/books").json():
        detail = client.get(f"/books/{b['id']}").json()
        snapshot.append(
            {
                "title": detail["title"],
                "cover_image": detail["cover_image"],
                "presentation": detail["presentation"],
                "chapters": chapters(b["id"]),
            }
        )
    return snapshot


def test_round_trip_restores_identical_library(client, populated, tmp_path, data_dir):
    archive = tmp_path / "biblioteca.recetarios"
    response = client.post("/library/export", json={"path": str(archive)})
    assert response.status_code == 200
    assert archive.is_file()

    before = _snapshot(client)

    # Import into a completely fresh installation.
    fresh_dir = tmp_path / "fresh"
    fresh_dir.mkdir()
    with TestClient(create_app(fresh_dir)) as fresh:
        result = fresh.post(
            "/library/import", json={"path": str(archive), "confirm_replace": True}
        )
        assert result.status_code == 200, result.text
        assert _snapshot(fresh) == before
        # Images restored and servable (SC-007).
        assert fresh.get(f"/images/{populated['image']}").status_code == 200


def test_import_replaces_existing_content(client, populated, tmp_path):
    archive = tmp_path / "lib.recetarios"
    client.post("/library/export", json={"path": str(archive)})
    before = _snapshot(client)

    # Extra content that must disappear after the replace-import.
    client.post("/books", json={"title": "Libro que sobra"})

    response = client.post(
        "/library/import", json={"path": str(archive), "confirm_replace": True}
    )
    assert response.status_code == 200
    assert _snapshot(client) == before


def test_import_requires_confirmation(client, populated, tmp_path):
    archive = tmp_path / "lib.recetarios"
    client.post("/library/export", json={"path": str(archive)})
    response = client.post("/library/import", json={"path": str(archive)})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "archive_confirm_required"


def test_corrupt_archive_leaves_library_intact(client, populated, tmp_path):
    before = _snapshot(client)
    bad = tmp_path / "corrupto.recetarios"
    bad.write_bytes(b"esto no es un zip")
    response = client.post(
        "/library/import", json={"path": str(bad), "confirm_replace": True}
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "archive_invalid"
    assert _snapshot(client) == before
