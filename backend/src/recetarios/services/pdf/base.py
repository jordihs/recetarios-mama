"""Shared PDF building blocks: styles and ContentBlock→Platypus converters.

Uses the built-in Helvetica family, whose Latin-1 coverage includes all
Spanish glyphs (SC-008). A4 page size per the spec assumption.
"""

from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import Image as RLImage
from reportlab.platypus import Paragraph, Spacer, Table, TableStyle

from recetarios.storage.images import ImageStore

PAGE_SIZE = A4
MARGIN = 2 * cm
CONTENT_WIDTH = PAGE_SIZE[0] - 2 * MARGIN

STYLES = {
    "cover_title": ParagraphStyle(
        "cover_title", fontName="Helvetica-Bold", fontSize=30, leading=36, alignment=1
    ),
    "book_intro": ParagraphStyle(
        "book_intro", fontName="Helvetica", fontSize=12, leading=16, alignment=1
    ),
    "toc_title": ParagraphStyle(
        "toc_title", fontName="Helvetica-Bold", fontSize=20, leading=24, spaceAfter=12
    ),
    "chapter_title": ParagraphStyle(
        "chapter_title", fontName="Helvetica-Bold", fontSize=22, leading=26, spaceAfter=12
    ),
    "recipe_title": ParagraphStyle(
        "recipe_title", fontName="Helvetica-Bold", fontSize=18, leading=22, spaceAfter=10
    ),
    "heading": ParagraphStyle(
        "heading", fontName="Helvetica-Bold", fontSize=14, leading=18, spaceBefore=8, spaceAfter=6
    ),
    "section": ParagraphStyle(
        "section", fontName="Helvetica-Bold", fontSize=13, leading=17, spaceBefore=10, spaceAfter=4
    ),
    "body": ParagraphStyle(
        "body", fontName="Helvetica", fontSize=10.5, leading=14.5, spaceAfter=6
    ),
    "caption": ParagraphStyle(
        "caption", fontName="Helvetica-Oblique", fontSize=8.5, leading=11,
        textColor=colors.grey, spaceAfter=6,
    ),
    "ingredient": ParagraphStyle(
        "ingredient", fontName="Helvetica", fontSize=10.5, leading=14.5, leftIndent=10
    ),
    "note": ParagraphStyle(
        "note", fontName="Helvetica-Oblique", fontSize=9.5, leading=13, spaceBefore=8
    ),
}


def spans_to_markup(spans: list[dict]) -> str:
    parts = []
    for span in spans:
        text = escape(span.get("text") or "")
        if span.get("bold"):
            text = f"<b>{text}</b>"
        if span.get("italic"):
            text = f"<i>{text}</i>"
        parts.append(text)
    return "".join(parts)


def _scaled_image(images: ImageStore, hash_: str, max_width: float, max_height: float):
    path = images.path_for(hash_)
    if path is None:
        return None
    row = images.db.conn.execute(
        "SELECT width, height FROM images WHERE hash = ?", (hash_,)
    ).fetchone()
    width = row["width"] or 400
    height = row["height"] or 300
    scale = min(max_width / width, max_height / height, 1.0)
    return RLImage(str(path), width=width * scale, height=height * scale)


def block_flowables(
    blocks: list[dict],
    images: ImageStore,
    include_images: bool = True,
    width: float = CONTENT_WIDTH,
) -> list:
    """Convert a content-block list into Platypus flowables."""
    flowables: list = []
    for block in blocks:
        kind = block.get("type")
        if kind == "heading":
            text = escape(block.get("text") or "")
            if text:
                flowables.append(Paragraph(text, STYLES["heading"]))
        elif kind == "paragraph":
            markup = spans_to_markup(block.get("spans") or [])
            if markup.strip():
                flowables.append(Paragraph(markup, STYLES["body"]))
        elif kind == "image" and include_images:
            image = _scaled_image(images, block.get("image") or "", width * 0.6, 9 * cm)
            if image is not None:
                flowables.append(image)
                if block.get("caption"):
                    flowables.append(Paragraph(escape(block["caption"]), STYLES["caption"]))
        elif kind == "image_group" and include_images:
            flowables.extend(_image_group(block, images, width))
        elif kind == "table":
            table = _table(block, images, include_images, width)
            if table is not None:
                flowables.extend(table)
    return flowables


def _image_group(block: dict, images: ImageStore, width: float) -> list:
    items = block.get("images") or []
    if not items:
        return []
    columns = min(len(items), 3 if block.get("layout") != "row" else len(items))
    cell_width = width / columns - 6
    cells, row = [], []
    for item in items:
        content = []
        image = _scaled_image(images, item.get("image") or "", cell_width, 6 * cm)
        if image is None:
            continue
        content.append(image)
        if item.get("caption"):
            content.append(Paragraph(escape(item["caption"]), STYLES["caption"]))
        row.append(content)
        if len(row) == columns:
            cells.append(row)
            row = []
    if row:
        row.extend([[]] * (columns - len(row)))
        cells.append(row)
    if not cells:
        return []
    table = Table(cells, colWidths=[width / columns] * columns)
    table.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    return [table, Spacer(0, 6)]


def _table(block: dict, images: ImageStore, include_images: bool, width: float):
    header = block.get("header") or []
    rows = block.get("rows") or []
    if not header and not rows:
        return None

    def cell_content(cell: dict):
        if cell.get("image") and include_images:
            image = _scaled_image(images, cell["image"], 4 * cm, 3 * cm)
            content = [image] if image is not None else []
            if cell.get("text"):
                content.append(Paragraph(escape(cell["text"]), STYLES["caption"]))
            return content
        return Paragraph(escape(cell.get("text") or ""), STYLES["body"])

    data = []
    if header:
        data.append([cell_content(c) for c in header])
    data.extend([[cell_content(c) for c in row] for row in rows])
    columns = max(len(r) for r in data)
    for row in data:
        row.extend([""] * (columns - len(row)))

    table = Table(data, colWidths=[width / columns] * columns, repeatRows=1 if header else 0)
    style = [
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]
    if header:
        style.append(("BACKGROUND", (0, 0), (-1, 0), colors.Color(0.93, 0.91, 0.88)))
        style.append(("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"))
    table.setStyle(TableStyle(style))
    flowables = []
    if block.get("title"):
        flowables.append(Paragraph(escape(block["title"]), STYLES["section"]))
    flowables.extend([table, Spacer(0, 6)])
    return flowables


def ingredient_flowables(ingredients: dict, label_servings: str | None = None) -> list:
    flowables: list = []
    servings = ingredients.get("servings")
    if servings:
        text = label_servings or f"Para {servings} personas"
        flowables.append(Paragraph(escape(text), STYLES["caption"]))
    for group in ingredients.get("groups") or []:
        if group.get("title"):
            flowables.append(Paragraph(escape(group["title"]), STYLES["section"]))
        for item in group.get("items") or []:
            flowables.append(Paragraph(f"• {escape(item)}", STYLES["ingredient"]))
    return flowables


def recipe_flowables(
    recipe: dict,
    images: ImageStore,
    include_introduction: bool = True,
    include_images: bool = True,
) -> list:
    """Recipe body used by both the book builder and the single-recipe PDF."""
    flowables: list = [Paragraph(escape(recipe["title"]), STYLES["recipe_title"])]
    if include_images and recipe.get("image"):
        image = _scaled_image(images, recipe["image"], CONTENT_WIDTH * 0.5, 8 * cm)
        if image is not None:
            flowables.append(image)
            flowables.append(Spacer(0, 8))
    if include_introduction and recipe.get("introduction"):
        flowables.extend(
            block_flowables(recipe["introduction"], images, include_images=include_images)
        )
    flowables.append(Paragraph("Ingredientes", STYLES["heading"]))
    flowables.extend(ingredient_flowables(recipe.get("ingredients") or {}))
    flowables.append(Paragraph("Preparación", STYLES["heading"]))
    flowables.extend(
        block_flowables(recipe.get("preparation") or [], images, include_images=include_images)
    )
    if recipe.get("note"):
        flowables.append(Paragraph(f"Nota: {escape(recipe['note'])}", STYLES["note"]))
    return flowables
