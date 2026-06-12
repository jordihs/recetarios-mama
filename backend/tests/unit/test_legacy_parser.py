"""US1 unit tests: v2 shape validation and per-block markdown emission."""

import json

import pytest

from recetarios.api.errors import ApiError
from recetarios.services.legacy_import.mapper import map_introduccion, map_recipe
from recetarios.services.legacy_import.parser import as_list, clean_text, load_document

HASH = "f" * 64


def _resolve(_src):
    return HASH  # every image resolves


def _drop(_src):
    return None  # no image resolves


class TestNormalization:
    def test_as_list_none(self):
        assert as_list(None) == []

    def test_as_list_single(self):
        assert as_list("x") == ["x"]
        assert as_list({"a": 1}) == [{"a": 1}]

    def test_as_list_passthrough(self):
        assert as_list([1, 2]) == [1, 2]

    def test_clean_text_collapses_xml_whitespace(self):
        assert clean_text("  Sopa \n\t de  ajo ") == "Sopa de ajo"


class TestBlockEmission:
    def test_parrafo_whitespace_normalized(self):
        intro = {"CONTENIDO": [{"tipo": "PARRAFO", "texto": "  Sopa \n de  ajo  "}]}
        result = map_introduccion(intro, _resolve)
        assert result.markdown == "Sopa de ajo"
        assert result.note is None

    def test_titulo_first_h2_subsequent_h3(self):
        intro = {
            "CONTENIDO": [
                {"tipo": "TITULO", "texto": "Las setas"},
                {"tipo": "PARRAFO", "texto": "Texto."},
                {"tipo": "TITULO", "texto": "Recolección"},
                {"tipo": "TITULO", "texto": "Conservación"},
            ]
        }
        result = map_introduccion(intro, _resolve)
        lines = result.markdown.split("\n\n")
        assert lines[0] == "## Las setas"
        assert lines[2] == "### Recolección"
        assert lines[3] == "### Conservación"

    def test_imagen_with_caption(self):
        intro = {
            "CONTENIDO": [
                {
                    "tipo": "IMAGEN",
                    "imagen": {"@attributes": {"src": "imgs/a.jpg"}, "#text": " Pie de foto "},
                }
            ]
        }
        result = map_introduccion(intro, _resolve)
        assert result.markdown == f"![Pie de foto](image://{HASH})"

    def test_unresolved_imagen_dropped(self):
        intro = {
            "CONTENIDO": [
                {"tipo": "IMAGEN", "imagen": {"@attributes": {"src": "imgs/nope.jpg"}}},
                {"tipo": "PARRAFO", "texto": "Queda esto."},
            ]
        }
        result = map_introduccion(intro, _drop)
        assert result.markdown == "Queda esto."

    def test_imagenes_gallery_consecutive_lines(self):
        intro = {
            "CONTENIDO": [
                {
                    "tipo": "IMAGENES",
                    "imagenes": [
                        {"@attributes": {"src": "imgs/a.jpg"}, "#text": "Una"},
                        {"@attributes": {"src": "imgs/b.jpg"}, "#text": "Dos"},
                    ],
                }
            ]
        }
        result = map_introduccion(intro, _resolve)
        assert result.markdown == (
            f"![Una](image://{HASH})\n![Dos](image://{HASH})"
        )

    def test_tabla_with_title_header_and_image_cell(self):
        intro = {
            "CONTENIDO": [
                {
                    "tipo": "TABLA",
                    "tabla": {
                        "@attributes": {"titulo": "Tiempos"},
                        "CABECERA": {"CELDA": [{"#text": "Especie"}, {"#text": "Minutos"}]},
                        "FILA": [
                            {
                                "CELDA": [
                                    {"@attributes": {"imagen": "imgs/c.jpg"}, "#text": "Níscalo"},
                                    {"#text": "5"},
                                ]
                            }
                        ],
                    },
                }
            ]
        }
        result = map_introduccion(intro, _resolve)
        assert result.markdown.startswith("**Tiempos**\n\n")
        assert "| Especie | Minutos |" in result.markdown
        assert f"| ![Níscalo](image://{HASH}) | 5 |" in result.markdown

    def test_tabla_without_cabecera_emits_empty_header(self):
        intro = {
            "CONTENIDO": [
                {
                    "tipo": "TABLA",
                    "tabla": {"FILA": [{"CELDA": [{"#text": "a"}, {"#text": "b"}]}]},
                }
            ]
        }
        result = map_introduccion(intro, _resolve)
        lines = result.markdown.splitlines()
        assert lines[0] == "|  |  |"
        assert set(lines[1].replace("|", "").replace(" ", "")) == {"-"}
        assert lines[2] == "| a | b |"

    def test_nota_lands_in_note_not_body(self):
        intro = {
            "CONTENIDO": [
                {"tipo": "PARRAFO", "texto": "Cuerpo."},
                {"tipo": "NOTA", "texto": "Primera nota."},
                {"tipo": "NOTA", "texto": "Segunda nota."},
            ]
        }
        result = map_introduccion(intro, _resolve)
        assert result.markdown == "Cuerpo."
        assert result.note == "Primera nota.\n\nSegunda nota."

    def test_source_order_preserved(self):
        intro = {
            "CONTENIDO": [
                {"tipo": "IMAGEN", "imagen": {"@attributes": {"src": "imgs/a.jpg"}}},
                {"tipo": "PARRAFO", "texto": "Uno."},
                {"tipo": "TITULO", "texto": "Título"},
                {"tipo": "PARRAFO", "texto": "Dos."},
            ]
        }
        result = map_introduccion(intro, _resolve)
        assert result.markdown == (
            f"![](image://{HASH})\n\nUno.\n\n## Título\n\nDos."
        )

    def test_empty_intro(self):
        assert map_introduccion(None, _resolve).markdown == ""
        assert map_introduccion({}, _resolve).markdown == ""


class TestRecipeMapping:
    def test_full_recipe(self):
        legacy = {
            "@attributes": {"imagen": "imgs/r.jpg"},
            "TITULO": " Tortilla ",
            "INGREDIENTES": {
                "@attributes": {"personas": "6"},
                "GRUPO": [
                    {"INGREDIENTE": ["Huevos", "Sal"]},
                    {"@attributes": {"titulo": "Para el aliño"}, "INGREDIENTE": "Aceite"},
                ],
            },
            "PREPARACION": ["Paso uno.", "Paso dos."],
            "NOTA": "Una nota",
        }
        recipe = map_recipe(legacy, _resolve)
        assert recipe.title == "Tortilla"
        assert recipe.image == HASH
        assert recipe.introduction == ""
        assert recipe.preparation == "Paso uno.\n\nPaso dos."
        assert recipe.ingredients.servings == "6"
        assert [g.items for g in recipe.ingredients.groups] == [["Huevos", "Sal"], ["Aceite"]]
        assert recipe.ingredients.groups[1].title == "Para el aliño"
        assert recipe.note == "Una nota"

    def test_preparacion_single_string(self):
        legacy = {
            "TITULO": "Simple",
            "INGREDIENTES": {"GRUPO": {"INGREDIENTE": "Agua"}},
            "PREPARACION": "Hervir.",
        }
        recipe = map_recipe(legacy, _drop)
        assert recipe.preparation == "Hervir."
        assert recipe.note is None

    def test_incomplete_recipe_missing_sections(self):
        recipe = map_recipe({"TITULO": "Solo título"}, _drop)
        assert recipe.title == "Solo título"
        assert recipe.ingredients.groups == []
        assert recipe.preparation == ""

    def test_nota_array_joined(self):
        legacy = {"TITULO": "Con notas", "NOTA": ["Nota uno.", "Nota dos."]}
        recipe = map_recipe(legacy, _drop)
        assert recipe.note == "Nota uno.\n\nNota dos."


class TestV1Detection:
    def _write(self, tmp_path, document):
        path = tmp_path / "libro.json"
        path.write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")
        return path

    def _v1_error(self, tmp_path, document):
        with pytest.raises(ApiError) as exc:
            load_document(self._write(tmp_path, document))
        assert exc.value.code == "legacy_v1_unsupported"

    def test_v1_grouped_intro_keys_rejected(self, tmp_path):
        self._v1_error(
            tmp_path,
            {
                "RECETARIO": {
                    "TITULO": "Viejo",
                    "INTRODUCCION": {"PARRAFO": ["uno", "dos"], "TITULO": "t"},
                    "CAPITULO": [],
                }
            },
        )

    def test_v1_string_intro_rejected(self, tmp_path):
        self._v1_error(
            tmp_path,
            {"RECETARIO": {"TITULO": "Viejo", "INTRODUCCION": "texto suelto", "CAPITULO": []}},
        )

    def test_v1_marker_in_chapter_intro_rejected(self, tmp_path):
        self._v1_error(
            tmp_path,
            {
                "RECETARIO": {
                    "TITULO": "Viejo",
                    "CAPITULO": [
                        {
                            "@attributes": {"nombre": "Cap"},
                            "INTRODUCCION": {"IMAGENES": {"IMAGEN": []}},
                        }
                    ],
                }
            },
        )

    def test_v2_document_accepted(self, tmp_path):
        document = {
            "RECETARIO": {
                "TITULO": "Nuevo",
                "INTRODUCCION": {"CONTENIDO": [{"tipo": "PARRAFO", "texto": "Hola"}]},
                "CAPITULO": [
                    {
                        "@attributes": {"nombre": "Cap"},
                        "INTRODUCCION": {"CONTENIDO": []},
                    }
                ],
            }
        }
        recetario = load_document(self._write(tmp_path, document))
        assert recetario["TITULO"] == "Nuevo"
