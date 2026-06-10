"""US5 unit tests: normalization of legacy single-or-array shapes and mapping."""

from recetarios.services.legacy_import.mapper import map_introduccion, map_recipe
from recetarios.services.legacy_import.parser import as_list, clean_text


def _resolve(_src):
    return "f" * 64  # every image resolves


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


class TestIntroduccionMapping:
    def test_paragraph_string_and_array(self):
        single = map_introduccion({"PARRAFO": "Hola"}, _resolve)
        multi = map_introduccion({"PARRAFO": ["Uno", "Dos"]}, _resolve)
        assert [b.type for b in single] == ["paragraph"]
        assert single[0].spans[0].text == "Hola"
        assert [b.spans[0].text for b in multi] == ["Uno", "Dos"]

    def test_titulo_becomes_heading(self):
        blocks = map_introduccion({"TITULO": "Sección", "PARRAFO": "x"}, _resolve)
        assert blocks[0].type == "heading"
        assert blocks[0].text == "Sección"

    def test_imagen_with_caption_floats_right(self):
        intro = {"IMAGEN": {"@attributes": {"src": "./imgs/a.jpg"}, "#text": "Pie"}}
        blocks = map_introduccion(intro, _resolve)
        assert blocks[0].type == "image"
        assert blocks[0].caption == "Pie"
        assert blocks[0].placement == "right"

    def test_imagenes_becomes_grid_group(self):
        intro = {
            "IMAGENES": {
                "IMAGEN": [
                    {"@attributes": {"src": "a.jpg"}},
                    {"@attributes": {"src": "b.jpg"}, "#text": "Pie"},
                ]
            }
        }
        blocks = map_introduccion(intro, _resolve)
        assert blocks[0].type == "image_group"
        assert blocks[0].layout == "grid"
        assert len(blocks[0].images) == 2
        assert blocks[0].images[1].caption == "Pie"

    def test_missing_images_are_dropped_and_reported(self):
        missing: list[str] = []

        def resolver(src):
            missing.append(src)
            return None

        intro = {"IMAGEN": {"@attributes": {"src": "imgs/gone.jpg"}}}
        blocks = map_introduccion(intro, resolver)
        assert blocks == []
        assert missing == ["imgs/gone.jpg"]

    def test_tabla_single_and_image_cells(self):
        intro = {
            "TABLA": {
                "@attributes": {"titulo": "Tiempos"},
                "CABECERA": {"CELDA": [{"#text": "Especie"}, {"#text": "Tiempo"}]},
                "FILA": {
                    "CELDA": [
                        {"#text": "Champiñón", "@attributes": {"imagen": "imgs/c.jpg"}},
                        {"#text": "5 min"},
                    ]
                },
            }
        }
        blocks = map_introduccion(intro, _resolve)
        assert blocks[0].type == "table"
        assert blocks[0].title == "Tiempos"
        assert [c.text for c in blocks[0].header] == ["Especie", "Tiempo"]
        assert blocks[0].rows[0][0].image == "f" * 64
        assert blocks[0].rows[0][0].text == "Champiñón"


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
        assert recipe.image == "f" * 64
        assert recipe.ingredients.servings == "6"
        assert recipe.ingredients.groups[0].items == ["Huevos", "Sal"]
        assert recipe.ingredients.groups[1].title == "Para el aliño"
        assert recipe.ingredients.groups[1].items == ["Aceite"]
        assert [b.spans[0].text for b in recipe.preparation] == ["Paso uno.", "Paso dos."]
        assert recipe.note == "Una nota"

    def test_preparacion_single_string(self):
        legacy = {
            "TITULO": "Simple",
            "INGREDIENTES": {"GRUPO": {"INGREDIENTE": "Agua"}},
            "PREPARACION": "Hervir.",
        }
        recipe = map_recipe(legacy, _drop)
        assert len(recipe.preparation) == 1
        assert recipe.ingredients.groups[0].items == ["Agua"]
        assert recipe.image is None
