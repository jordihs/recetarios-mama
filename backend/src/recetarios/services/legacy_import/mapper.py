"""Legacy v2 → markdown mapping (see data-model.md mapping table).

`map_introduccion` walks the ordered ``CONTENIDO`` array emitting one markdown
block per element — order in equals order out (SC-001). ``NOTA`` blocks are
collected into a separate note value, never into the body (FR-004).

Image references are resolved through a caller-provided `resolve(src) -> hash`
callable; unresolvable images are dropped from the content (the importer
records them in the report).
"""

from collections.abc import Callable
from typing import NamedTuple

from recetarios.models.entities import IngredientGroup, IngredientsList, RecipeInput
from recetarios.services.legacy_import.parser import as_list, attr, clean_text

Resolver = Callable[[str], str | None]


class MappedIntro(NamedTuple):
    markdown: str
    note: str | None


def _image_line(node: dict, resolve: Resolver) -> str | None:
    src = attr(node, "src")
    if not src:
        return None
    hash_ = resolve(src)
    if hash_ is None:
        return None
    caption = clean_text(node.get("#text"))
    return f"![{caption}](image://{hash_})"


def _cell_markdown(cell, resolve: Resolver) -> str:
    if not isinstance(cell, dict):
        return _escape_cell(clean_text(cell))
    text = clean_text(cell.get("#text"))
    image_src = attr(cell, "imagen")
    if image_src:
        image_hash = resolve(image_src)
        if image_hash is not None:
            return f"![{_escape_cell(text)}](image://{image_hash})"
    return _escape_cell(text)


def _escape_cell(text: str) -> str:
    return text.replace("|", "\\|")


def _table_markdown(node: dict, resolve: Resolver) -> str:
    rows = [as_list((row or {}).get("CELDA")) for row in as_list(node.get("FILA"))]
    header = as_list((node.get("CABECERA") or {}).get("CELDA"))
    columns = max([len(header), *(len(r) for r in rows)] or [0])
    if columns == 0:
        return ""

    def line(cells) -> str:
        rendered = [_cell_markdown(cell, resolve) for cell in cells]
        rendered += [""] * (columns - len(rendered))
        return "| " + " | ".join(rendered) + " |"

    lines = [
        line(header) if header else "|" + "  |" * columns,
        "|" + " --- |" * columns,
        *(line(row) for row in rows),
    ]
    table = "\n".join(lines)
    title = attr(node, "titulo")
    return f"**{title}**\n\n{table}" if title else table


def map_introduccion(intro: dict | None, resolve: Resolver) -> MappedIntro:
    """Ordered CONTENIDO walk → (markdown document, separate note)."""
    blocks: list[str] = []
    notes: list[str] = []
    first_title = True
    for element in (intro or {}).get("CONTENIDO") or []:
        if not isinstance(element, dict):
            continue
        tipo = element.get("tipo")
        if tipo == "TITULO":
            text = clean_text(element.get("texto"))
            if text:
                blocks.append(("## " if first_title else "### ") + text)
                first_title = False
        elif tipo == "PARRAFO":
            text = clean_text(element.get("texto"))
            if text:
                blocks.append(text)
        elif tipo == "IMAGEN":
            line = _image_line(element.get("imagen") or {}, resolve)
            if line:
                blocks.append(line)
        elif tipo == "IMAGENES":
            lines = [
                line
                for image in element.get("imagenes") or []
                if (line := _image_line(image or {}, resolve))
            ]
            if lines:
                blocks.append("\n".join(lines))
        elif tipo == "TABLA":
            table = _table_markdown(element.get("tabla") or {}, resolve)
            if table:
                blocks.append(table)
        elif tipo == "NOTA":
            text = clean_text(element.get("texto"))
            if text:
                notes.append(text)
    return MappedIntro(
        markdown="\n\n".join(blocks),
        note="\n\n".join(notes) or None,
    )


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

    preparation = "\n\n".join(
        cleaned for p in as_list(legacy.get("PREPARACION")) if (cleaned := clean_text(p))
    )
    note = "\n\n".join(
        cleaned
        for n in as_list(legacy.get("NOTA") or legacy.get("nota"))
        if (cleaned := clean_text(n))
    )

    return RecipeInput(
        title=clean_text(legacy.get("TITULO")) or "(sin título)",
        image=image_hash,
        introduction="",
        ingredients=IngredientsList(servings=attr(ingredientes, "personas"), groups=groups),
        preparation=preparation,
        note=note or None,
    )
