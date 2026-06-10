"""US1: books CRUD, reorder, derived description, cascade delete."""


def _make_book(client, title="Recetas de mamá", description=None):
    presentation = []
    if description is not None:
        presentation.append({"type": "paragraph", "spans": [{"text": description}]})
    response = client.post("/books", json={"title": title, "presentation": presentation})
    assert response.status_code == 200, response.text
    return response.json()


def test_create_and_list_books(client):
    _make_book(client, "Libro A", "Las mejores recetas de la familia")
    _make_book(client, "Libro B")

    response = client.get("/books")
    assert response.status_code == 200
    books = response.json()
    assert [b["title"] for b in books] == ["Libro A", "Libro B"]
    assert books[0]["description"] == "Las mejores recetas de la familia"
    assert books[1]["description"] == ""


def test_description_derived_from_first_paragraph(client):
    book = _make_book(client, "Con bloques")
    response = client.put(
        f"/books/{book['id']}",
        json={
            "title": "Con bloques",
            "presentation": [
                {"type": "heading", "text": "Un título"},
                {"type": "paragraph", "spans": [{"text": "Primer párrafo."}]},
                {"type": "paragraph", "spans": [{"text": "Segundo."}]},
            ],
        },
    )
    assert response.status_code == 200
    listed = client.get("/books").json()
    assert listed[0]["description"] == "Primer párrafo."


def test_get_book_detail(client):
    book = _make_book(client, "Detalle", "desc")
    response = client.get(f"/books/{book['id']}")
    assert response.status_code == 200
    detail = response.json()
    assert detail["title"] == "Detalle"
    assert detail["presentation"][0]["type"] == "paragraph"


def test_update_book(client):
    book = _make_book(client, "Antes")
    response = client.put(f"/books/{book['id']}", json={"title": "Después"})
    assert response.status_code == 200
    assert client.get(f"/books/{book['id']}").json()["title"] == "Después"


def test_title_validation(client):
    response = client.post("/books", json={"title": "   "})
    assert response.status_code in (400, 422)
    response = client.post("/books", json={"title": "x" * 201})
    assert response.status_code in (400, 422)


def test_unknown_cover_image_rejected(client):
    response = client.post("/books", json={"title": "Foto", "cover_image": "0" * 64})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_image_ref"


def test_delete_book(client):
    book = _make_book(client, "Borrar")
    response = client.delete(f"/books/{book['id']}")
    assert response.status_code == 200
    assert client.get(f"/books/{book['id']}").status_code == 404
    assert client.get("/books").json() == []


def test_reorder_books(client):
    a = _make_book(client, "A")
    b = _make_book(client, "B")
    c = _make_book(client, "C")
    response = client.put("/books/order", json={"ids": [c["id"], a["id"], b["id"]]})
    assert response.status_code == 200
    assert [x["title"] for x in client.get("/books").json()] == ["C", "A", "B"]


def test_reorder_requires_full_permutation(client):
    a = _make_book(client, "A")
    _make_book(client, "B")
    response = client.put("/books/order", json={"ids": [a["id"]]})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_order"


def test_missing_book_404(client):
    response = client.get("/books/nope")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "book_not_found"
