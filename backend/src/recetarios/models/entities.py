"""Domain entities: Book, Chapter, Recipe and their embedded structures."""

from pydantic import BaseModel, Field, field_validator

from recetarios.models.markdown import (
    MAX_DOCUMENT_BYTES,
    plain_text,
    referenced_images,
)

MAX_TITLE = 200


def _validate_title(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("title must not be empty")
    if len(value) > MAX_TITLE:
        raise ValueError(f"title must be at most {MAX_TITLE} characters")
    return value


def _validate_markdown(value: str) -> str:
    if len(value.encode("utf-8")) > MAX_DOCUMENT_BYTES:
        raise ValueError(
            f"document must be at most {MAX_DOCUMENT_BYTES} bytes"
        )
    return value


class IngredientGroup(BaseModel):
    title: str | None = None
    items: list[str] = Field(default_factory=list)


class IngredientsList(BaseModel):
    servings: str | None = None
    groups: list[IngredientGroup] = Field(default_factory=list)

    def plain_text(self) -> str:
        parts: list[str] = []
        for group in self.groups:
            if group.title:
                parts.append(group.title)
            parts.extend(group.items)
        return "\n".join(parts)


class BookInput(BaseModel):
    title: str
    cover_image: str | None = None
    presentation: str = ""
    note: str | None = None

    _title = field_validator("title")(_validate_title)
    _presentation = field_validator("presentation")(_validate_markdown)


class ChapterInput(BaseModel):
    title: str
    parent_chapter_id: str | None = None
    cover_image: str | None = None
    presentation: str = ""
    note: str | None = None

    _title = field_validator("title")(_validate_title)
    _presentation = field_validator("presentation")(_validate_markdown)


class RecipeInput(BaseModel):
    title: str
    image: str | None = None
    introduction: str = ""
    ingredients: IngredientsList = Field(default_factory=IngredientsList)
    preparation: str = ""
    note: str | None = None

    _title = field_validator("title")(_validate_title)
    _documents = field_validator("introduction", "preparation")(_validate_markdown)

    def referenced_images(self) -> set[str]:
        refs = referenced_images(self.introduction) | referenced_images(
            self.preparation
        )
        if self.image:
            refs.add(self.image)
        return refs

    def search_texts(self) -> dict[str, str]:
        return {
            "title": self.title,
            "ingredients": self.ingredients.plain_text(),
            "preparation": plain_text(self.preparation),
            "introduction": plain_text(self.introduction),
        }
