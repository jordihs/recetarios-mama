"""Content block model: the canonical rich-content representation.

Mirrors the legacy INTRODUCCION structures one-to-one (see data-model.md)
and feeds screen rendering, editing, and PDF building alike.
"""

from typing import Annotated, Literal

from pydantic import BaseModel, Field


class Span(BaseModel):
    text: str
    bold: bool = False
    italic: bool = False


class HeadingBlock(BaseModel):
    type: Literal["heading"] = "heading"
    text: str


class ParagraphBlock(BaseModel):
    type: Literal["paragraph"] = "paragraph"
    spans: list[Span] = Field(default_factory=list)

    def plain_text(self) -> str:
        return "".join(s.text for s in self.spans)


class ImageBlock(BaseModel):
    type: Literal["image"] = "image"
    image: str
    caption: str | None = None
    placement: Literal["right", "block"] = "block"


class ImageGroupItem(BaseModel):
    image: str
    caption: str | None = None


class ImageGroupBlock(BaseModel):
    type: Literal["image_group"] = "image_group"
    images: list[ImageGroupItem] = Field(default_factory=list)
    layout: Literal["grid", "row"] = "grid"


class Cell(BaseModel):
    text: str | None = None
    image: str | None = None


class TableBlock(BaseModel):
    type: Literal["table"] = "table"
    title: str | None = None
    header: list[Cell] = Field(default_factory=list)
    rows: list[list[Cell]] = Field(default_factory=list)


ContentBlock = Annotated[
    HeadingBlock | ParagraphBlock | ImageBlock | ImageGroupBlock | TableBlock,
    Field(discriminator="type"),
]


def blocks_plain_text(blocks: list[ContentBlock]) -> str:
    """Flatten blocks to plain text (description derivation, FTS indexing)."""
    parts: list[str] = []
    for block in blocks:
        if isinstance(block, HeadingBlock):
            parts.append(block.text)
        elif isinstance(block, ParagraphBlock):
            parts.append(block.plain_text())
        elif isinstance(block, ImageBlock):
            if block.caption:
                parts.append(block.caption)
        elif isinstance(block, ImageGroupBlock):
            parts.extend(i.caption for i in block.images if i.caption)
        elif isinstance(block, TableBlock):
            if block.title:
                parts.append(block.title)
            for row in [block.header, *block.rows]:
                parts.extend(c.text for c in row if c.text)
    return "\n".join(p.strip() for p in parts if p and p.strip())


def first_paragraph_text(blocks: list[ContentBlock]) -> str:
    """Derived list 'description': text of the first paragraph block."""
    for block in blocks:
        if isinstance(block, ParagraphBlock):
            text = block.plain_text().strip()
            if text:
                return text
    return ""


def referenced_image_hashes(blocks: list[ContentBlock]) -> set[str]:
    refs: set[str] = set()
    for block in blocks:
        if isinstance(block, ImageBlock):
            refs.add(block.image)
        elif isinstance(block, ImageGroupBlock):
            refs.update(i.image for i in block.images)
        elif isinstance(block, TableBlock):
            for row in [block.header, *block.rows]:
                refs.update(c.image for c in row if c.image)
    return refs
