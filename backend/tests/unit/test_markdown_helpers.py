"""Foundational: markdown helper module (plain text, first paragraph, image refs)."""

from recetarios.models.markdown import (
    first_paragraph,
    md_tokens,
    plain_text,
    referenced_images,
)

HASH_A = "a" * 64
HASH_B = "b" * 64

DOC = f"""## Las setas

Un párrafo con **negrita** y *cursiva*.

![Pie de foto](image://{HASH_A})

![Galería uno](image://{HASH_A})
![Galería dos](image://{HASH_B})

**Tabla de tiempos**

| Especie | Tiempo |
| --- | --- |
| ![Champiñón](image://{HASH_B}) | 5 min |

### Subsección

Otro párrafo.
"""


def test_plain_text_strips_syntax_keeps_captions_and_cells():
    text = plain_text(DOC)
    assert "Las setas" in text
    assert "negrita" in text and "**" not in text
    assert "Pie de foto" in text  # image caption preserved
    assert "Champiñón" in text and "5 min" in text  # table cells
    assert "image://" not in text


def test_first_paragraph_skips_headings_and_galleries():
    assert first_paragraph(DOC) == "Un párrafo con negrita y cursiva."
    gallery_first = f"![a](image://{HASH_A})\n\nTexto real."
    assert first_paragraph(gallery_first) == "Texto real."
    assert first_paragraph("## Solo título") == ""
    assert first_paragraph("") == ""


def test_referenced_images_extracts_hashes():
    assert referenced_images(DOC) == {HASH_A, HASH_B}
    assert referenced_images("sin imágenes") == set()


def test_tokens_include_gfm_table():
    types = [t.type for t in md_tokens(DOC)]
    assert "table_open" in types
    assert "heading_open" in types
