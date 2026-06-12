"""US1 golden tests against the three real v2 books in legacy/ (SC-001/002).

The core guarantee is *ordering*: for every introduction, the element sequence
of the stored markdown must equal the source `CONTENIDO` sequence (machine
checked). Counting/preservation tests from feature 002 are retained on the
markdown model.
"""

import json

import pytest
from tests.conftest import LEGACY_DIR

from recetarios.models.markdown import md_tokens
from recetarios.services.legacy_import.parser import clean_text

BOOKS = sorted(LEGACY_DIR.glob("*.json"))


def _as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def _resolvable(src: str) -> bool:
    """Mirror the importer's file lookup (relative path, case-insensitive)."""
    relative = (src or "").strip().lstrip("./").replace("\\", "/")
    if not relative:
        return False
    path = LEGACY_DIR / relative
    if path.is_file():
        return True
    parent = path.parent
    if parent.is_dir():
        lowered = path.name.lower()
        return any(entry.name.lower() == lowered for entry in parent.iterdir())
    return False


def _expected_sequence(intro: dict | None) -> list[str]:
    """Source CONTENIDO → kind sequence, with unresolvable images dropped."""
    sequence: list[str] = []
    first_title = True
    for block in (intro or {}).get("CONTENIDO", []):
        tipo = block.get("tipo")
        if tipo == "NOTA":
            continue  # never in the body
        if tipo == "TITULO":
            if clean_text(block.get("texto")):  # empty titles are dropped
                sequence.append("h2" if first_title else "h3")
                first_title = False
        elif tipo == "PARRAFO":
            if clean_text(block.get("texto")):
                sequence.append("p")
        elif tipo == "IMAGEN":
            src = ((block.get("imagen") or {}).get("@attributes") or {}).get("src")
            if _resolvable(src):
                sequence.append("image")
        elif tipo == "IMAGENES":
            resolved = sum(
                1
                for image in block.get("imagenes") or []
                if _resolvable((image.get("@attributes") or {}).get("src"))
            )
            if resolved == 1:
                sequence.append("image")
            elif resolved > 1:
                sequence.append("gallery")
        elif tipo == "TABLA":
            sequence.append("table")
    return sequence


def _markdown_sequence(markdown: str) -> list[str]:
    """Stored markdown → kind sequence (table title lines belong to the table)."""
    tokens = md_tokens(markdown)
    sequence: list[str] = []
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token.type == "heading_open":
            sequence.append(token.tag)
            i += 3
        elif token.type == "paragraph_open":
            inline = tokens[i + 1]
            # markdown-it pads the inline with empty text children.
            children = [
                c
                for c in inline.children or []
                if not (c.type == "text" and not c.content)
            ]
            images = [c for c in children if c.type == "image"]
            text = "".join(c.content for c in children if c.type == "text").strip()
            fully_bold = (
                len(children) >= 3
                and children[0].type == "strong_open"
                and children[-1].type == "strong_close"
            )
            table_follows = i + 3 < len(tokens) and tokens[i + 3].type == "table_open"
            if images and not text:
                sequence.append("image" if len(images) == 1 else "gallery")
            elif fully_bold and table_follows:
                pass  # table title line, accounted for with the table
            else:
                sequence.append("p")
            i += 3
        elif token.type == "table_open":
            sequence.append("table")
            depth = 0
            while i < len(tokens):
                depth += tokens[i].nesting
                i += 1
                if depth == 0:
                    break
        else:
            i += 1
    return sequence


def _import(client, path, on_collision="keep_both"):
    response = client.post(
        "/import/legacy", json={"path": str(path), "on_collision": on_collision}
    )
    assert response.status_code == 200, response.text
    return response.json()


def _zip_walk(client, book_id, source):
    """Pair every imported chapter detail with its source chapter, in order."""
    pairs = []

    def walk(parent_id, source_chapters):
        api_chapters = client.get(
            f"/books/{book_id}/chapters",
            params={} if parent_id is None else {"parent": parent_id},
        ).json()
        source_chapters = _as_list(source_chapters)
        assert len(api_chapters) == len(source_chapters)
        for api_summary, source_chapter in zip(api_chapters, source_chapters, strict=True):
            detail = client.get(f"/chapters/{api_summary['id']}").json()
            pairs.append((detail, source_chapter))
            walk(api_summary["id"], source_chapter.get("CAPITULO"))

    walk(None, source.get("CAPITULO"))
    return pairs


# ---------------------------------------------------------------- SC-001 core


@pytest.mark.parametrize("path", BOOKS, ids=[p.stem[:20] for p in BOOKS])
def test_introduction_order_matches_source(client, path):
    source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]
    result = _import(client, path)

    book = client.get(f"/books/{result['book_id']}").json()
    assert _markdown_sequence(book["presentation"]) == _expected_sequence(
        source.get("INTRODUCCION")
    )

    for detail, source_chapter in _zip_walk(client, result["book_id"], source):
        expected = _expected_sequence(source_chapter.get("INTRODUCCION"))
        actual = _markdown_sequence(detail["presentation"])
        assert actual == expected, (
            f"order mismatch in chapter '{detail['title']}':"
            f" expected {expected}, got {actual}"
        )


def test_multi_title_intro_h2_then_h3(client):
    """The first TITULO becomes the H2 section; later ones are H3 subsections."""
    for path in BOOKS:
        source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]
        result = _import(client, path)
        for detail, source_chapter in _zip_walk(client, result["book_id"], source):
            titles = [
                b
                for b in (source_chapter.get("INTRODUCCION") or {}).get("CONTENIDO", [])
                if b.get("tipo") == "TITULO"
            ]
            if len(titles) < 2:
                continue
            sequence = _markdown_sequence(detail["presentation"])
            headings = [k for k in sequence if k in ("h2", "h3")]
            assert headings[0] == "h2"
            assert set(headings[1:]) == {"h3"}
            return  # one verified multi-title intro is enough
    pytest.fail("no multi-title introduction found in the sample books")


def test_nota_blocks_become_note_field(client):
    found = 0
    for path in BOOKS:
        source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]
        result = _import(client, path)
        for detail, source_chapter in _zip_walk(client, result["book_id"], source):
            notas = [
                clean_text(b.get("texto"))
                for b in (source_chapter.get("INTRODUCCION") or {}).get("CONTENIDO", [])
                if b.get("tipo") == "NOTA"
            ]
            if not notas:
                continue
            found += 1
            assert detail["note"], f"chapter '{detail['title']}' lost its NOTA"
            for nota in notas:
                assert nota in detail["note"]
                assert nota not in detail["presentation"]
    assert found > 0, "no NOTA blocks found in the sample books"


# ------------------------------------------------------- preservation (SC-002)


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


def _walk_api(client, book_id, parent=None):
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
    path = next(p for p in BOOKS if "como_ingrediente" in p.name)
    result = _import(client, path)
    top = client.get(f"/books/{result['book_id']}/chapters").json()
    nested_parents = [c for c in top if c["has_subchapters"]]
    assert nested_parents, "expected at least one top-level chapter with subchapters"
    sub = client.get(
        f"/books/{result['book_id']}/chapters", params={"parent": nested_parents[0]["id"]}
    ).json()
    assert sub, "subchapters must be reachable through the API"


def test_tables_preserved_in_presentations(client):
    path = next(p for p in BOOKS if p.name == "recetas_de_mama.json")
    source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]

    def count_source_tables(intro):
        return sum(
            1 for b in (intro or {}).get("CONTENIDO", []) if b.get("tipo") == "TABLA"
        )

    result = _import(client, path)
    book = client.get(f"/books/{result['book_id']}").json()
    expected = count_source_tables(source.get("INTRODUCCION"))
    total = _markdown_sequence(book["presentation"]).count("table")
    for detail, source_chapter in _zip_walk(client, result["book_id"], source):
        expected += count_source_tables(source_chapter.get("INTRODUCCION"))
        total += _markdown_sequence(detail["presentation"]).count("table")
    assert expected > 0
    assert total == expected


def test_incomplete_recipes_imported(client):
    """Recipes without INGREDIENTES/PREPARACION import with empty sections."""
    for path in BOOKS:
        source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]

        def find_incomplete(chapters):
            for chapter in _as_list(chapters):
                for recipe in _as_list(chapter.get("RECETA")):
                    if "INGREDIENTES" not in recipe or "PREPARACION" not in recipe:
                        return recipe
                found = find_incomplete(chapter.get("CAPITULO"))
                if found:
                    return found
            return None

        incomplete = find_incomplete(source.get("CAPITULO"))
        if incomplete is None:
            continue
        result = _import(client, path)
        title = clean_text(incomplete["TITULO"])

        def find_imported(book_id, parent=None, title=title):
            for chapter in client.get(
                f"/books/{book_id}/chapters",
                params={} if parent is None else {"parent": parent},
            ).json():
                for summary in client.get(f"/chapters/{chapter['id']}/recipes").json():
                    if summary["title"] == title:
                        return client.get(f"/recipes/{summary['id']}").json()
                found = find_imported(book_id, chapter["id"])
                if found:
                    return found
            return None

        imported = find_imported(result["book_id"])
        assert imported is not None, f"incomplete recipe '{title}' missing after import"
        if "INGREDIENTES" not in incomplete:
            assert imported["ingredients"]["groups"] == []
        if "PREPARACION" not in incomplete:
            assert imported["preparation"] == ""
        return
    pytest.fail("no incomplete recipe found in the sample books")


def test_recipe_nota_array_joined(client):
    for path in BOOKS:
        source = json.loads(path.read_text(encoding="utf-8"))["RECETARIO"]

        def find_array_nota(chapters):
            for chapter in _as_list(chapters):
                for recipe in _as_list(chapter.get("RECETA")):
                    if isinstance(recipe.get("NOTA"), list):
                        return recipe
                found = find_array_nota(chapter.get("CAPITULO"))
                if found:
                    return found
            return None

        recipe = find_array_nota(source.get("CAPITULO"))
        if recipe is None:
            continue
        result = _import(client, path)
        title = clean_text(recipe["TITULO"])

        def find_imported(book_id, parent=None, title=title):
            for chapter in client.get(
                f"/books/{book_id}/chapters",
                params={} if parent is None else {"parent": parent},
            ).json():
                for summary in client.get(f"/chapters/{chapter['id']}/recipes").json():
                    if summary["title"] == title:
                        return client.get(f"/recipes/{summary['id']}").json()
                found = find_imported(book_id, chapter["id"])
                if found:
                    return found
            return None

        imported = find_imported(result["book_id"])
        assert imported is not None
        for nota in recipe["NOTA"]:
            assert clean_text(nota) in imported["note"]
        return
    pytest.fail("no recipe with a NOTA array found in the sample books")


def test_images_imported_and_resolvable(client):
    path = next(p for p in BOOKS if p.name == "recetas_de_mama.json")
    result = _import(client, path)
    report = result["report"]
    assert report["images_imported"] > 0

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

    _import(client, path, on_collision="replace")
    titles = [b["title"] for b in client.get("/books").json()]
    assert titles.count(inspect["book_title"]) == 1

    _import(client, path, on_collision="keep_both")
    titles = [b["title"] for b in client.get("/books").json()]
    assert titles.count(inspect["book_title"]) == 2


# --------------------------------------------------------------- v1 rejection


def test_v1_document_rejected(client, tmp_path):
    v1_document = {
        "RECETARIO": {
            "TITULO": "Recetario antiguo",
            "INTRODUCCION": {"PARRAFO": ["uno", "dos"], "IMAGEN": []},
            "CAPITULO": [],
        }
    }
    path = tmp_path / "viejo.json"
    path.write_text(json.dumps(v1_document, ensure_ascii=False), encoding="utf-8")

    response = client.post(
        "/import/legacy", json={"path": str(path), "on_collision": "keep_both"}
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "legacy_v1_unsupported"

    inspect = client.post("/import/legacy/inspect", json={"path": str(path)})
    assert inspect.status_code == 400
    assert inspect.json()["error"]["code"] == "legacy_v1_unsupported"


def test_missing_file_reports_clear_error(client):
    response = client.post(
        "/import/legacy", json={"path": str(LEGACY_DIR / "nope.json"), "on_collision": "keep_both"}
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "legacy_file_not_found"
