"""Shared PDF building blocks: styles and markdown→Platypus converters.

Markdown (CommonMark + GFM tables, the canonical content format) is parsed
with markdown-it and its token stream mapped onto the existing flowable
vocabulary: headings, body paragraphs, bullet lists, image lines with
captions, gallery paragraphs as image grids, and tables (with an optional
bold title line directly above).

Uses the built-in Helvetica family, whose Latin-1 coverage includes all
Spanish glyphs (SC-008). A4 page size per the spec assumption.
"""

from xml.sax.saxutils import escape

from markdown_it.token import Token
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import Image as RLImage
from reportlab.platypus import Paragraph, Spacer, Table, TableStyle

from recetarios.models.markdown import md_tokens
from recetarios.storage.images import ImageStore

PAGE_SIZE = A4
MARGIN = 2 * cm
CONTENT_WIDTH = PAGE_SIZE[0] - 2 * MARGIN

_IMAGE_URI_PREFIX = "image://"

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


def image_flowables(
    images: ImageStore,
    hash_: str,
    caption: str | None = None,
    width: float = CONTENT_WIDTH,
) -> list:
    """A single block image with optional caption (covers, image lines)."""
    image = _scaled_image(images, hash_, width * 0.6, 9 * cm)
    if image is None:
        return []
    flowables: list = [image]
    if caption:
        flowables.append(Paragraph(escape(caption), STYLES["caption"]))
    return flowables


def _inline_markup(token: Token) -> str:
    """Inline token → ReportLab paragraph markup (text only; images excluded)."""
    parts: list[str] = []
    for child in token.children or []:
        kind = child.type
        if kind in ("text", "code_inline"):
            parts.append(escape(child.content))
        elif kind == "strong_open":
            parts.append("<b>")
        elif kind == "strong_close":
            parts.append("</b>")
        elif kind == "em_open":
            parts.append("<i>")
        elif kind == "em_close":
            parts.append("</i>")
        elif kind in ("softbreak", "hardbreak"):
            parts.append("<br/>")
    return "".join(parts)


def _inline_images(token: Token) -> list[tuple[str, str]]:
    """(hash, caption) pairs for every image:// reference in an inline token."""
    found: list[tuple[str, str]] = []
    for child in token.children or []:
        if child.type != "image":
            continue
        src = child.attrGet("src") or ""
        if not src.startswith(_IMAGE_URI_PREFIX):
            continue
        found.append((src[len(_IMAGE_URI_PREFIX):], child.content or ""))
    return found


def _is_fully_bold(token: Token) -> bool:
    # markdown-it pads the inline with empty text children around the strong.
    children = [
        c for c in token.children or [] if not (c.type == "text" and not c.content)
    ]
    if len(children) < 3:
        return False
    return (
        children[0].type == "strong_open"
        and children[-1].type == "strong_close"
        and all(c.type == "text" for c in children[1:-1])
    )


def markdown_flowables(
    text: str,
    images: ImageStore,
    include_images: bool = True,
    width: float = CONTENT_WIDTH,
) -> list:
    """Convert a markdown document into Platypus flowables."""
    tokens = md_tokens(text or "")
    flowables: list = []
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token.type == "heading_open":
            inline = tokens[i + 1]
            style = STYLES["section"] if token.tag == "h3" else STYLES["heading"]
            markup = _inline_markup(inline)
            if markup.strip():
                flowables.append(Paragraph(markup, style))
            i += 3
        elif token.type == "paragraph_open":
            inline = tokens[i + 1]
            table_follows = i + 3 < len(tokens) and tokens[i + 3].type == "table_open"
            flowables.extend(
                _paragraph_flowables(
                    inline,
                    images,
                    include_images,
                    width,
                    as_table_title=table_follows and _is_fully_bold(inline),
                )
            )
            i += 3
        elif token.type in ("bullet_list_open", "ordered_list_open"):
            close = _matching_close(tokens, i)
            flowables.extend(_list_flowables(tokens[i + 1 : close]))
            i = close + 1
        elif token.type == "table_open":
            close = _matching_close(tokens, i)
            flowables.extend(
                _table_flowables(tokens[i + 1 : close], images, include_images, width)
            )
            i = close + 1
        else:
            i += 1
    return flowables


def _matching_close(tokens: list[Token], start: int) -> int:
    depth = 0
    for idx in range(start, len(tokens)):
        depth += tokens[idx].nesting
        if depth == 0:
            return idx
    return len(tokens) - 1


def _paragraph_flowables(
    inline: Token,
    images: ImageStore,
    include_images: bool,
    width: float,
    as_table_title: bool = False,
) -> list:
    image_refs = _inline_images(inline)
    markup = _inline_markup(inline)
    flowables: list = []
    if markup.strip():
        style = STYLES["section"] if as_table_title else STYLES["body"]
        flowables.append(Paragraph(markup, style))
    if include_images and image_refs:
        if len(image_refs) > 1 and not markup.strip():
            # Gallery paragraph (image lines only) → grid.
            flowables.extend(_image_grid(image_refs, images, width))
        else:
            for hash_, caption in image_refs:
                flowables.extend(image_flowables(images, hash_, caption, width))
    return flowables


def _list_flowables(tokens: list[Token]) -> list:
    flowables: list = []
    for token in tokens:
        if token.type == "inline":
            markup = _inline_markup(token)
            if markup.strip():
                flowables.append(Paragraph(f"• {markup}", STYLES["ingredient"]))
    return flowables


def _image_grid(
    image_refs: list[tuple[str, str]], images: ImageStore, width: float
) -> list:
    columns = min(len(image_refs), 3)
    cell_width = width / columns - 6
    cells, row = [], []
    for hash_, caption in image_refs:
        image = _scaled_image(images, hash_, cell_width, 6 * cm)
        if image is None:
            continue
        content: list = [image]
        if caption:
            content.append(Paragraph(escape(caption), STYLES["caption"]))
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


def _table_flowables(
    tokens: list[Token], images: ImageStore, include_images: bool, width: float
) -> list:
    """GFM table tokens (between table_open/table_close) → Platypus table."""
    has_header = any(t.type == "th_open" for t in tokens)
    data: list[list] = []
    image_cells: list[tuple[int, int]] = []  # (col, row) with images
    current_row: list | None = None
    cell_inline: Token | None = None
    for token in tokens:
        if token.type == "tr_open":
            current_row = []
        elif token.type == "tr_close":
            if current_row is not None:
                data.append(current_row)
            current_row = None
        elif token.type in ("th_open", "td_open"):
            cell_inline = None
        elif token.type == "inline":
            cell_inline = token
        elif token.type in ("th_close", "td_close") and current_row is not None:
            if cell_inline is not None and _inline_images(cell_inline):
                image_cells.append((len(current_row), len(data)))
            current_row.append(
                _cell_content(cell_inline, images, include_images)
            )
    if not data:
        return []
    columns = max(len(r) for r in data)
    for row in data:
        row.extend([""] * (columns - len(row)))

    table = Table(
        data, colWidths=[width / columns] * columns, repeatRows=1 if has_header else 0
    )
    style = [
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]
    if has_header:
        style.append(("BACKGROUND", (0, 0), (-1, 0), colors.Color(0.93, 0.91, 0.88)))
        style.append(("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"))
    # Image-bearing cells bottom-align their content (FR-021), so texts sit
    # at a uniform baseline regardless of image heights.
    style.extend(("VALIGN", cell, cell, "BOTTOM") for cell in image_cells)
    table.setStyle(TableStyle(style))
    return [table, Spacer(0, 6)]


def _cell_content(inline: Token | None, images: ImageStore, include_images: bool):
    if inline is None:
        return ""
    image_refs = _inline_images(inline)
    markup = _inline_markup(inline)
    if image_refs and include_images:
        content: list = []
        for hash_, caption in image_refs:
            image = _scaled_image(images, hash_, 4 * cm, 3 * cm)
            if image is not None:
                content.append(image)
            text = markup.strip() or escape(caption)
            if text:
                content.append(Paragraph(text, STYLES["caption"]))
        return content
    if image_refs and not include_images and not markup.strip():
        # Image-only cell with images suppressed: fall back to the caption.
        caption = next((c for _, c in image_refs if c), "")
        return Paragraph(escape(caption), STYLES["body"]) if caption else ""
    return Paragraph(markup, STYLES["body"])


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
            markdown_flowables(recipe["introduction"], images, include_images=include_images)
        )
    flowables.append(Paragraph("Ingredientes", STYLES["heading"]))
    flowables.extend(ingredient_flowables(recipe.get("ingredients") or {}))
    flowables.append(Paragraph("Preparación", STYLES["heading"]))
    flowables.extend(
        markdown_flowables(recipe.get("preparation") or "", images, include_images=include_images)
    )
    if recipe.get("note"):
        flowables.append(Paragraph(f"Nota: {escape(recipe['note'])}", STYLES["note"]))
    return flowables
