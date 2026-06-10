"""Single-recipe PDF honoring include-introduction / include-images (FR-031/032)."""

from pathlib import Path

from reportlab.platypus import SimpleDocTemplate

from recetarios.services.library import LibraryService
from recetarios.services.pdf.base import MARGIN, PAGE_SIZE, recipe_flowables
from recetarios.services.pdf.book_builder import safe_filename
from recetarios.storage.images import ImageStore


class RecipePdfBuilder:
    def __init__(self, library: LibraryService, images: ImageStore):
        self.library = library
        self.images = images

    def build(
        self,
        recipe_id: str,
        output_dir: Path,
        include_introduction: bool,
        include_images: bool,
    ) -> Path:
        recipe = self.library.get_recipe(recipe_id)
        output_path = Path(output_dir) / f"{safe_filename(recipe['title'])}.pdf"
        doc = SimpleDocTemplate(
            str(output_path),
            pagesize=PAGE_SIZE,
            leftMargin=MARGIN,
            rightMargin=MARGIN,
            topMargin=MARGIN,
            bottomMargin=MARGIN,
            title=recipe["title"],
        )
        doc.build(
            recipe_flowables(
                recipe,
                self.images,
                include_introduction=include_introduction,
                include_images=include_images,
            )
        )
        return output_path
