"""Domain entities: Book, Chapter, Recipe and their embedded structures."""

from pydantic import BaseModel, Field, field_validator

from recetarios.models.blocks import ContentBlock, blocks_plain_text, referenced_image_hashes

MAX_TITLE = 200


def _validate_title(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("title must not be empty")
    if len(value) > MAX_TITLE:
        raise ValueError(f"title must be at most {MAX_TITLE} characters")
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
    presentation: list[ContentBlock] = Field(default_factory=list)

    _title = field_validator("title")(_validate_title)


class ChapterInput(BaseModel):
    title: str
    parent_chapter_id: str | None = None
    cover_image: str | None = None
    presentation: list[ContentBlock] = Field(default_factory=list)

    _title = field_validator("title")(_validate_title)


class RecipeInput(BaseModel):
    title: str
    image: str | None = None
    introduction: list[ContentBlock] = Field(default_factory=list)
    ingredients: IngredientsList = Field(default_factory=IngredientsList)
    preparation: list[ContentBlock] = Field(default_factory=list)
    note: str | None = None

    _title = field_validator("title")(_validate_title)

    def referenced_images(self) -> set[str]:
        refs = referenced_image_hashes(self.introduction) | referenced_image_hashes(
            self.preparation
        )
        if self.image:
            refs.add(self.image)
        return refs

    def search_texts(self) -> dict[str, str]:
        return {
            "title": self.title,
            "ingredients": self.ingredients.plain_text(),
            "preparation": blocks_plain_text(self.preparation),
            "introduction": blocks_plain_text(self.introduction),
        }
