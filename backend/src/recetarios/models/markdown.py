"""Markdown helpers: the single place where stored markdown is interpreted.

Dialect: CommonMark + GFM tables. Image references use `image://<sha256>`
URIs (alt text is the caption). Consumers: FTS indexing and list descriptions
(plain text), write-time validation and archive export (image refs), and the
PDF builders (token stream).
"""

import re

from markdown_it import MarkdownIt
from markdown_it.token import Token

_md = MarkdownIt("commonmark").enable("table")

_IMAGE_REF = re.compile(r"image://([0-9a-fA-F]{64})")

MAX_DOCUMENT_BYTES = 1024 * 1024


def md_tokens(text: str) -> list[Token]:
    return _md.parse(text or "")


def _inline_text(token: Token, include_captions: bool = True) -> str:
    """Plain text of an inline token: visible text plus image captions."""
    parts: list[str] = []
    for child in token.children or []:
        if child.type in ("text", "code_inline"):
            parts.append(child.content)
        elif child.type == "image" and include_captions:
            # Alt text (the caption) lives in the nested children.
            caption = "".join(
                grand.content for grand in child.children or [] if grand.type == "text"
            )
            if caption:
                parts.append(caption)
        elif child.type == "softbreak":
            parts.append(" ")
    return "".join(parts).strip()


def plain_text(text: str) -> str:
    """Flatten a markdown document to searchable plain text."""
    lines: list[str] = []
    for token in md_tokens(text):
        if token.type == "inline":
            extracted = _inline_text(token)
            if extracted:
                lines.append(extracted)
    return "\n".join(lines)


def first_paragraph(text: str) -> str:
    """Plain text of the first paragraph with visible text (list descriptions)."""
    tokens = md_tokens(text)
    in_paragraph = False
    for token in tokens:
        if token.type == "paragraph_open":
            in_paragraph = True
        elif token.type == "paragraph_close":
            in_paragraph = False
        elif token.type == "inline" and in_paragraph:
            # Caption-only paragraphs (image galleries) are not descriptions.
            extracted = _inline_text(token, include_captions=False)
            if extracted:
                return extracted
    return ""


def referenced_images(text: str) -> set[str]:
    """All image-store hashes referenced by a markdown document."""
    return {match.lower() for match in _IMAGE_REF.findall(text or "")}


def referenced_images_ordered(text: str) -> list[str]:
    """Image-store hashes in document order (image fallback pass, FR-017)."""
    seen: set[str] = set()
    ordered: list[str] = []
    for match in _IMAGE_REF.findall(text or ""):
        hash_ = match.lower()
        if hash_ not in seen:
            seen.add(hash_)
            ordered.append(hash_)
    return ordered
