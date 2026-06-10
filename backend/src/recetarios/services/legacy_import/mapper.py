"""Legacy → application model mapping (see data-model.md mapping table).

Image references are resolved through a caller-provided `resolve(src) -> hash`
callable; unresolvable images are dropped from the content (the importer
records them in the report).
"""

from collections.abc import Callable

from recetarios.models.blocks import (
    Cell,
    ContentBlock,
    HeadingBlock,
    ImageBlock,
    ImageGroupBlock,
    ImageGroupItem,
    ParagraphBlock,
    Span,
    TableBlock,
)
from recetarios.models.entities import IngredientGroup, IngredientsList, RecipeInput
from recetarios.services.legacy_import.parser import as_list, attr, clean_text

Resolver = Callable[[str], str | None]


def _paragraph(text: str) -> ParagraphBlock:
    return ParagraphBlock(spans=[Span(text=text)])


def _map_image(node: dict, resolve: Resolver, placement: str) -> ImageBlock | None:
    src = attr(node, "src")
    if not src:
        return None
    hash_ = resolve(src)
    if hash_ is None:
        return None
    caption = clean_text(node.get("#text")) or None
    return ImageBlock(image=hash_, caption=caption, placement=placement)


def _map_cells(node, resolve: Resolver) -> list[Cell]:
    cells = []
    for cell in as_list((node or {}).get("CELDA")):
        if not isinstance(cell, dict):
            cells.append(Cell(text=clean_text(cell) or None))
            continue
        image_src = attr(cell, "imagen")
        image_hash = resolve(image_src) if image_src else None
        cells.append(Cell(text=clean_text(cell.get("#text")) or None, image=image_hash))
    return cells


def _map_table(node: dict, resolve: Resolver) -> TableBlock:
    return TableBlock(
        title=attr(node, "titulo"),
        header=_map_cells(node.get("CABECERA"), resolve),
        rows=[_map_cells(row, resolve) for row in as_list(node.get("FILA"))],
    )


def map_introduccion(intro: dict | None, resolve: Resolver) -> list[ContentBlock]:
    """Map a legacy INTRODUCCION to content blocks.

    The JSON conversion lost the original element interleaving, so a stable
    order is emitted: heading, floating images, paragraphs, image groups,
    tables. The renderer floats `right` images beside the next paragraph,
    matching the old XSL layout.
    """
    if not intro:
        return []
    # Some real documents carry a bare string instead of the structured object.
    if isinstance(intro, str):
        text = clean_text(intro)
        return [_paragraph(text)] if text else []
    blocks: list[ContentBlock] = []
    title = clean_text(intro.get("TITULO"))
    if title:
        blocks.append(HeadingBlock(text=title))
    for image_node in as_list(intro.get("IMAGEN")):
        block = _map_image(image_node, resolve, placement="right")
        if block:
            blocks.append(block)
    for text in as_list(intro.get("PARRAFO")):
        cleaned = clean_text(text)
        if cleaned:
            blocks.append(_paragraph(cleaned))
    for group_node in as_list(intro.get("IMAGENES")):
        items = []
        for image_node in as_list((group_node or {}).get("IMAGEN")):
            src = attr(image_node, "src")
            hash_ = resolve(src) if src else None
            if hash_ is not None:
                caption = clean_text(image_node.get("#text")) or None
                items.append(ImageGroupItem(image=hash_, caption=caption))
        if items:
            blocks.append(ImageGroupBlock(images=items, layout="grid"))
    for table_node in as_list(intro.get("TABLA")):
        blocks.append(_map_table(table_node, resolve))
    return blocks


def map_recipe(legacy: dict, resolve: Resolver) -> RecipeInput:
    image_src = attr(legacy, "imagen")
    image_hash = resolve(image_src) if image_src else None

    ingredientes = legacy.get("INGREDIENTES") or {}
    groups = []
    for group_node in as_list(ingredientes.get("GRUPO")):
        items = [clean_text(i) for i in as_list((group_node or {}).get("INGREDIENTE"))]
        groups.append(
            IngredientGroup(
                title=attr(group_node or {}, "titulo"),
                items=[i for i in items if i],
            )
        )

    preparation = [
        _paragraph(clean_text(p)) for p in as_list(legacy.get("PREPARACION")) if clean_text(p)
    ]
    note = clean_text(legacy.get("NOTA") or legacy.get("nota")) or None

    return RecipeInput(
        title=clean_text(legacy.get("TITULO")) or "(sin título)",
        image=image_hash,
        introduction=[],
        ingredients=IngredientsList(servings=attr(ingredientes, "personas"), groups=groups),
        preparation=preparation,
        note=note,
    )
