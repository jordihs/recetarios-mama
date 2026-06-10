"""US2: nested chapters CRUD, reorder, cycle prevention, cascade delete."""

import pytest


@pytest.fixture()
def book_id(client):
    return client.post("/books", json={"title": "Libro"}).json()["id"]


def _make_chapter(client, book_id, title, parent=None, description=None):
    presentation = []
    if description is not None:
        presentation.append({"type": "paragraph", "spans": [{"text": description}]})
    response = client.post(
        f"/books/{book_id}/chapters",
        json={"title": title, "parent_chapter_id": parent, "presentation": presentation},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_create_and_list_top_level_chapters(client, book_id):
    _make_chapter(client, book_id, "Entrantes", description="Para abrir boca")
    _make_chapter(client, book_id, "Guisos")

    response = client.get(f"/books/{book_id}/chapters")
    assert response.status_code == 200
    chapters = response.json()
    assert [c["title"] for c in chapters] == ["Entrantes", "Guisos"]
    assert chapters[0]["description"] == "Para abrir boca"
    assert chapters[0]["has_subchapters"] is False
    assert chapters[0]["recipe_count"] == 0


def test_nested_chapters(client, book_id):
    parent = _make_chapter(client, book_id, "Setas")
    _make_chapter(client, book_id, "Preparación", parent=parent["id"])

    top = client.get(f"/books/{book_id}/chapters").json()
    assert [c["title"] for c in top] == ["Setas"]
    assert top[0]["has_subchapters"] is True

    nested = client.get(f"/books/{book_id}/chapters", params={"parent": parent["id"]}).json()
    assert [c["title"] for c in nested] == ["Preparación"]


def test_chapter_detail_and_update(client, book_id):
    chapter = _make_chapter(client, book_id, "Antes")
    detail = client.get(f"/chapters/{chapter['id']}").json()
    assert detail["title"] == "Antes"
    assert detail["book_id"] == book_id

    response = client.put(
        f"/chapters/{chapter['id']}",
        json={"title": "Después", "parent_chapter_id": None},
    )
    assert response.status_code == 200
    assert client.get(f"/chapters/{chapter['id']}").json()["title"] == "Después"


def test_parent_must_be_same_book(client, book_id):
    other_book = client.post("/books", json={"title": "Otro"}).json()["id"]
    foreign = _make_chapter(client, other_book, "Ajeno")
    response = client.post(
        f"/books/{book_id}/chapters",
        json={"title": "Mal", "parent_chapter_id": foreign["id"]},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_parent_chapter"


def test_cycle_rejected(client, book_id):
    a = _make_chapter(client, book_id, "A")
    b = _make_chapter(client, book_id, "B", parent=a["id"])
    response = client.put(
        f"/chapters/{a['id']}",
        json={"title": "A", "parent_chapter_id": b["id"]},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_parent_chapter"


def test_self_parent_rejected(client, book_id):
    a = _make_chapter(client, book_id, "A")
    response = client.put(
        f"/chapters/{a['id']}",
        json={"title": "A", "parent_chapter_id": a["id"]},
    )
    assert response.status_code == 400


def test_cascade_delete_subchapters(client, book_id):
    parent = _make_chapter(client, book_id, "Padre")
    child = _make_chapter(client, book_id, "Hijo", parent=parent["id"])

    response = client.delete(f"/chapters/{parent['id']}")
    assert response.status_code == 200
    assert client.get(f"/chapters/{child['id']}").status_code == 404


def test_reorder_siblings(client, book_id):
    a = _make_chapter(client, book_id, "A")
    b = _make_chapter(client, book_id, "B")
    response = client.put(
        "/chapters/order",
        json={"book_id": book_id, "parent_chapter_id": None, "ids": [b["id"], a["id"]]},
    )
    assert response.status_code == 200
    assert [c["title"] for c in client.get(f"/books/{book_id}/chapters").json()] == ["B", "A"]


def test_reorder_rejects_partial(client, book_id):
    a = _make_chapter(client, book_id, "A")
    _make_chapter(client, book_id, "B")
    response = client.put(
        "/chapters/order",
        json={"book_id": book_id, "parent_chapter_id": None, "ids": [a["id"]]},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_order"


def test_missing_chapter_404(client):
    assert client.get("/chapters/nope").status_code == 404
