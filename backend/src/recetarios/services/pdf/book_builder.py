"""Whole-book PDF (FR-029/030): cover, indented index with page numbers,
chapter introduction pages, and every recipe starting on a new page."""

import re
import unicodedata
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
)
from reportlab.platypus.tableofcontents import TableOfContents

from recetarios.services.library import LibraryService
from recetarios.services.pdf.base import (
    CONTENT_WIDTH,
    MARGIN,
    PAGE_SIZE,
    STYLES,
    image_flowables,
    markdown_flowables,
    recipe_flowables,
)
from recetarios.storage.images import ImageStore

# Style-name → TOC level: chapters indent by nesting depth, recipes one deeper.
_TOC_PATTERN = re.compile(r"^toc_entry_(\d+)$")

_TOC_LEVEL_STYLES = [
    ParagraphStyle(f"toc_level_{level}", fontName="Helvetica", fontSize=11,
                   leading=16, leftIndent=14 * level)
    for level in range(5)
]


class _BookDocTemplate(BaseDocTemplate):
    """Notifies TOC entries for paragraphs whose style is toc_entry_<level>."""

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph):
            match = _TOC_PATTERN.match(flowable.style.name)
            if match:
                level = int(match.group(1))
                text = flowable.getPlainText()
                self.notify("TOCEntry", (level, text, self.page))


def _entry_style(level: int, base: ParagraphStyle) -> ParagraphStyle:
    """Clone a heading style under a toc_entry_<level> name."""
    return ParagraphStyle(f"toc_entry_{level}", parent=base)


def safe_filename(title: str) -> str:
    normalized = unicodedata.normalize("NFKD", title)
    ascii_title = normalized.encode("ascii", "ignore").decode()
    cleaned = re.sub(r"[^\w\s-]", "", ascii_title).strip()
    return re.sub(r"[\s]+", "_", cleaned) or "recetario"


class BookPdfBuilder:
    def __init__(self, library: LibraryService, images: ImageStore):
        self.library = library
        self.images = images

    def build(self, book_id: str, output_dir: Path) -> Path:
        book = self.library.get_book(book_id)
        output_path = Path(output_dir) / f"{safe_filename(book['title'])}.pdf"

        doc = _BookDocTemplate(
            str(output_path),
            pagesize=PAGE_SIZE,
            leftMargin=MARGIN,
            rightMargin=MARGIN,
            topMargin=MARGIN,
            bottomMargin=MARGIN,
            title=book["title"],
        )
        frame = Frame(MARGIN, MARGIN, CONTENT_WIDTH, PAGE_SIZE[1] - 2 * MARGIN, id="main")
        doc.addPageTemplates([PageTemplate(id="main", frames=[frame])])

        story: list = []
        # --- Cover page ---
        story.append(Spacer(0, 5 * cm))
        story.append(Paragraph(escape(book["title"]), STYLES["cover_title"]))
        story.append(Spacer(0, 1 * cm))
        if book.get("cover_image"):
            story.extend(image_flowables(self.images, book["cover_image"]))
        story.extend(markdown_flowables(book.get("presentation") or "", self.images))
        story.append(NextPageTemplate("main"))
        story.append(PageBreak())

        # --- Index (multi-pass TOC) ---
        toc = TableOfContents()
        toc.levelStyles = _TOC_LEVEL_STYLES
        story.append(Paragraph("Índice", STYLES["toc_title"]))
        story.append(toc)
        story.append(PageBreak())

        # --- Chapters (recursive) ---
        self._chapter_story(story, book_id, None, level=0)

        doc.multiBuild(story)
        return output_path

    def _chapter_story(self, story: list, book_id: str, parent_id: str | None, level: int):
        chapters = self.library.list_chapters(book_id, parent_id)
        for summary in chapters:
            chapter = self.library.get_chapter(summary["id"])
            # Chapter introduction page.
            story.append(
                Paragraph(
                    escape(chapter["title"]),
                    _entry_style(level, STYLES["chapter_title"]),
                )
            )
            if chapter.get("cover_image"):
                story.extend(image_flowables(self.images, chapter["cover_image"]))
            story.extend(markdown_flowables(chapter.get("presentation") or "", self.images))

            # Every recipe begins on a new page (FR-030).
            for recipe_summary in self.library.list_recipes(chapter["id"]):
                recipe = self.library.get_recipe(recipe_summary["id"])
                story.append(PageBreak())
                flowables = recipe_flowables(recipe, self.images)
                # Re-style the title paragraph so it lands in the TOC.
                flowables[0] = Paragraph(
                    escape(recipe["title"]), _entry_style(level + 1, STYLES["recipe_title"])
                )
                story.extend(flowables)

            # Subchapters start on their own page.
            subchapters = self.library.list_chapters(book_id, chapter["id"])
            if subchapters:
                story.append(PageBreak())
                self._chapter_story(story, book_id, chapter["id"], level + 1)

            if summary is not chapters[-1]:
                story.append(PageBreak())
