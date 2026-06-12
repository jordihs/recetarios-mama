"""US5: generated PDF tables bottom-align exactly the image-bearing cells."""

import io

import pytest
from PIL import Image
from reportlab.platypus import Table

from recetarios.services.pdf.base import markdown_flowables
from recetarios.storage.db import Database
from recetarios.storage.images import ImageStore


@pytest.fixture()
def images(tmp_path):
    db = Database(tmp_path)
    store = ImageStore(db)
    yield store
    db.close()


def _ingest(images: ImageStore) -> str:
    buf = io.BytesIO()
    Image.new("RGB", (40, 30), "brown").save(buf, format="PNG")
    return images.ingest(buf.getvalue())["hash"]


def _bottom_cells(table: Table) -> list[tuple[int, int]]:
    """(col, row) of every cell whose applied style is bottom-aligned."""
    return sorted(
        (col, row)
        for row, row_styles in enumerate(table._cellStyles)  # noqa: SLF001
        for col, cell_style in enumerate(row_styles)
        if cell_style.valign == "BOTTOM"
    )


def test_image_cells_get_bottom_valign(images):
    hash_ = _ingest(images)
    markdown = (
        "| Especie | Foto | Tiempo |\n"
        "| --- | --- | --- |\n"
        f"| Níscalo | ![Níscalo](image://{hash_}) | 5 min |\n"
        f"| Champiñón | texto solo | ![Champi](image://{hash_}) |\n"
    )
    tables = [f for f in markdown_flowables(markdown, images) if isinstance(f, Table)]
    assert len(tables) == 1
    # Exactly the two image cells: (col 1, row 1) and (col 2, row 2).
    assert _bottom_cells(tables[0]) == [(1, 1), (2, 2)]


def test_text_only_table_has_no_bottom_valign(images):
    markdown = "| A | B |\n| --- | --- |\n| uno | dos |\n"
    tables = [f for f in markdown_flowables(markdown, images) if isinstance(f, Table)]
    assert len(tables) == 1
    assert _bottom_cells(tables[0]) == []
