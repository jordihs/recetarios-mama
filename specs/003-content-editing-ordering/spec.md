# Feature Specification: Content Editing & Legacy Ordering

**Feature Branch**: `003-content-editing-ordering`

**Created**: 2026-06-11

**Status**: Draft

**Input**: User description: "The JSON schema originally used to create the application was incorrect. The original data format supported blocks of unordered elements such as titles, paragraphs and tables. But due to a conversion error, these were grouped together, such that for an introduction with several titles across the text, the titles were grouped under a single array, thus losing the relationship to where in the text the title should appear. The JSON schema has been corrected and updated, and the sample recipe books are also updated to conform to the updated schema. The application code should be updated to work with the new schema, preserving the ordering of elements that was lost in the previous version. Also related, the way the application stores and edits introduction text is not user friendly or efficient. When importing the legacy data, all information from introduction sections, with the exception of notes, should be collapsed into a single markdown document. When editing this content (or any other, as the user may need to add richer content to say a preparation section, which originally does not allow anything other than paragraphs), the application should present a rich text editor, with a source and preview (defaulting to the preview, with source button not prominent since it will not be used frequently). This editor should have the usual buttons and functionality associated with rich text editing, such as options to add bold text, titles, lists, tables, images, etc. If this affects the database schema, where paragraphs may be stored separately, then it should be updated to reflect the new situation. Therefore, the current way the user adds and edits new paragraphs, with a separate add paragraph function that shows a text input, should not be necessary. The user will simply write and edit paragraphs in the rich text editor for the whole introduction. With regards to this, when importing a legacy introduction that contains more than one title, it will be assumed that the first title is the main section title, while the remaining ones will mark subsections and thus should be interpreted as lower level titles and displayed as such. The resulting imported documents often appear poorly in the UI because of the lack of images in the original. As a fallback procedure, when importing an element that does not contain an image (or references a missing link), the process will search for a child element that does contain an image and assign it to the parent. That is, if the book has no image or the image is not found, the introduction and chapters, and their underlying recipes will be searched until a valid image reference is found, and it will be assigned to the book. Same for chapters. Recipes with no image will be left without an image, as in that case the resulting picture may be misleading to readers. On elements that have no image, the size of the text block remains half the size of their containing card, which is not visually appealing. The application should allow for more text to be displayed on cards without images. Some table cells contain images and text. Currently, the application displays the text immediately under the image, resulting in a misaligned row, where text appears at different heights depending on image size. This should be corrected by vertically aligning text to the bottom of the cells whenever the cell contains an image."

## Clarifications

### Session 2026-06-11

- Q: What happens to content already stored in the current per-block format (existing library and old backup archives)? → A: No migration — the old library is not converted; the user re-imports the schema-v2 legacy books. Old backup archives are rejected with a clear message.
- Q: What does the importer do with a legacy file in the obsolete grouped (v1) shape? → A: Reject it with a clear Spanish error identifying the format as unsupported (confirms FR-007 as written).
- Q: Which heading levels do multi-title introductions get on import? → A: First title → level-2 heading, all subsequent titles → level-3 headings (the item's own name acts as level 1).
- Q: Does the bottom-aligned text fix for image-bearing table cells apply to printed PDFs too? → A: Yes — screen and PDF render the same alignment.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ordered Legacy Import (Schema v2) (Priority: P1)

As the owner of the legacy recipe collection, I want the import to read the corrected legacy format (where introduction elements carry their original document order) so that titles, paragraphs, images, and tables appear in my books exactly where they appeared in the source document, instead of regrouped by type.

**Why this priority**: The previous import scrambled real content — a section title separated from its section is wrong data, not just bad presentation. Every other story builds on correctly ordered content.

**Independent Test**: Import each of the three updated sample books from `legacy/` and verify that, for an introduction containing interleaved titles, paragraphs, images, and tables, the displayed sequence matches the order of the source document's content list exactly.

**Acceptance Scenarios**:

1. **Given** a legacy book in the corrected format, **When** it is imported, **Then** every introduction's elements (titles, paragraphs, single images, image galleries, tables) appear in exactly the source order.
2. **Given** an introduction containing more than one title, **When** imported, **Then** the first title becomes the main section title and each subsequent title becomes a lower-level (subsection) heading, and they are displayed with that hierarchy.
3. **Given** an introduction containing note elements, **When** imported, **Then** the notes are kept out of the introduction body and displayed separately as notes (in the same style as recipe notes).
4. **Given** a legacy recipe that lacks an ingredients list or a preparation section (the corpus contains incomplete recipes), **When** imported, **Then** the recipe is created with the missing sections empty rather than rejected, and the import completes.
5. **Given** a legacy recipe whose note field contains several notes, **When** imported, **Then** all of them are preserved in the recipe's note.

---

### User Story 2 - Single-Document Rich Text Editing (Priority: P2)

As a home cook editing my books, I want each introduction (and any rich content section, such as a recipe's preparation) to be one continuous document I can write in a rich text editor — with the usual formatting tools and a preview-first interface — so that I no longer have to add and manage paragraphs one input box at a time.

**Why this priority**: This replaces the most cumbersome interaction in the application. It depends on content being stored as a single document, which the import change (US1) establishes.

**Independent Test**: Open a book introduction for editing, write several paragraphs with a subsection title, bold text, a list, and an inserted image in one editing surface, switch between preview and source views, save, and verify the rendered result. Confirm no "add paragraph" button exists anywhere.

**Acceptance Scenarios**:

1. **Given** any rich content section (book/chapter introduction, recipe introduction, recipe preparation), **When** the user edits it, **Then** a single rich text editor presents the whole content as one document — there is no separate per-paragraph add/edit control.
2. **Given** the rich text editor, **When** it opens, **Then** it shows the formatted preview by default, with an unobtrusive control to switch to the source view and back.
3. **Given** the editor toolbar, **When** the user applies formatting, **Then** at minimum bold text, titles (heading levels), lists, tables, and image insertion are available.
4. **Given** legacy-imported content, **When** opened in the editor, **Then** everything that was imported (headings hierarchy, paragraphs, images with captions, galleries, tables) is present and editable in the document.
5. **Given** an edit session, **When** the user saves or discards, **Then** the existing save/discard semantics (including the unsaved-changes warning) continue to apply.

---

### User Story 3 - Image Fallback on Import (Priority: P3)

As a reader browsing imported books, I want books and chapters that have no image of their own to automatically receive a representative image from their contents, so that the library does not look bare when the original documents carried few images.

**Why this priority**: Pure presentation improvement of imported data; valuable but meaningless until ordered import (US1) works.

**Independent Test**: Import a sample book whose root has no image and verify the book card shows an image taken from its contents; verify a chapter without an image shows one found in its recipes; verify a recipe without an image remains imageless.

**Acceptance Scenarios**:

1. **Given** a legacy book with no image (or whose image reference cannot be resolved), **When** imported, **Then** the book is assigned the first valid image found by searching its introduction, then its chapters and their contents (subchapters and recipes), in document order.
2. **Given** a chapter with no valid image of its own, **When** imported, **Then** it is assigned the first valid image found within it (its introduction, subchapters, recipes), in document order.
3. **Given** a recipe with no image, **When** imported, **Then** it remains without an image — recipes never inherit images.
4. **Given** a book or chapter where no descendant contains any valid image, **When** imported, **Then** it simply remains without an image and the import succeeds.

---

### User Story 4 - Fuller Text on Imageless Cards (Priority: P4)

As a reader browsing lists, I want cards for items without an image to use the freed space for more description text, so that imageless cards don't look half empty.

**Why this priority**: Small visual fix, independent of the rest.

**Independent Test**: Place an item with a long description and no image next to one with an image; verify the imageless card fills its card area with text (more visible lines than the card with an image) while keeping the ellipsis truncation at the limit.

**Acceptance Scenarios**:

1. **Given** a list card for an item without an image, **When** rendered, **Then** the description text area expands to use the space an image would occupy, showing more text before truncation.
2. **Given** a list card for an item with an image, **When** rendered, **Then** the current layout (image plus truncated description) is unchanged.

---

### User Story 5 - Aligned Table Cells With Images (Priority: P5)

As a reader viewing tables that mix image cells and text cells, I want cell text vertically aligned to the bottom whenever the cell contains an image, so that rows read evenly regardless of image heights.

**Why this priority**: Small visual fix, independent of the rest.

**Independent Test**: Display an imported table whose row mixes image+text cells with text-only cells of varying image sizes and verify the texts of image-bearing cells sit at the bottom edge of their cells, visually aligned across the row.

**Acceptance Scenarios**:

1. **Given** a table cell containing an image and text, **When** rendered, **Then** the text is aligned to the bottom of the cell.
2. **Given** a row with several image+text cells of differing image heights, **When** rendered, **Then** all their texts appear at the same bottom baseline.
3. **Given** text-only cells, **When** rendered, **Then** their alignment is unchanged.

---

### Edge Cases

- Re-importing a book previously imported with the old (unordered) import: the existing replace-or-keep-both collision flow applies; replacing yields the correctly ordered version.
- A library created before this change is detected on startup: the user is informed and offered a reset; the app never renders or saves over old-format content as if it were valid.
- An introduction whose only content is notes: the body is empty, the notes still display.
- A legacy document in the old (v1) shape — grouped arrays without ordered content lists: the import reports a clear unsupported-format error in Spanish rather than importing scrambled data.
- Source view edits that produce malformed markup: the preview renders best-effort; saving never corrupts the stored content.
- Image insertion in the editor when the user cancels the file picker: no change to the document.
- Fallback image search where the first found image is in a deeply nested subchapter's recipe: it is still found (search covers the whole subtree in document order).
- Tables in markdown content that carry image cells must continue to round-trip into the printed PDFs (book and recipe) with the same fidelity as today, including the new bottom alignment.
- Full-text search must keep indexing the text of rich content after the storage change (search results unchanged or better).
- Library backup archives created before this change must either import correctly (content migrated) or be rejected with a clear message — never silently mangled.

## Requirements *(mandatory)*

### Functional Requirements

#### Ordered Legacy Import (Schema v2)

- **FR-001**: The legacy import MUST read the corrected legacy format, in which each introduction carries a single ordered list of content elements (titles, paragraphs, single images, image galleries, tables, notes), and MUST preserve that order in the imported content.
- **FR-002**: The import MUST NOT regroup elements by type; the displayed order of an imported introduction MUST match the source order element-for-element.
- **FR-003**: When an introduction contains more than one title element, the import MUST map the first to a level-2 heading (the item's own name acts as level 1) and every subsequent title to a level-3 heading, and the application MUST display them as visibly distinct levels.
- **FR-004**: All introduction content except notes MUST be collapsed into a single rich text document (markdown) per introduction; note elements MUST be kept separate from the body and displayed as notes, in the same visual style as recipe notes.
- **FR-005**: The import MUST accept incomplete legacy recipes — recipes lacking ingredients and/or preparation are created with those sections empty.
- **FR-006**: The import MUST accept recipe notes given as either a single text or a list of texts, preserving all of them.
- **FR-007**: A legacy document in the obsolete grouped (v1) shape MUST be rejected with a clear Spanish error message identifying the format as unsupported.

#### Single-Document Content & Rich Text Editing

- **FR-008**: Rich content sections (book introduction, chapter introduction, recipe introduction, recipe preparation) MUST be stored and edited as one continuous document each, not as separately managed paragraph blocks; the stored representation MUST be updated accordingly.
- **FR-009**: Editing any rich content section MUST present a rich text editor over the whole document, with no separate "add paragraph" interaction anywhere in the application.
- **FR-010**: The editor MUST offer a formatted preview and a raw source view; the preview is the default, and the source toggle is present but visually unobtrusive.
- **FR-011**: The editor MUST provide standard formatting controls including at minimum: bold, titles/headings, lists, tables, and image insertion. Images inserted through the editor MUST be incorporated into the application's image storage as today.
- **FR-012**: All content capabilities that exist today MUST remain expressible after the change: headings, paragraphs, emphasized text, images with captions, image groups/galleries, and tables (including cells that contain an image with text).
- **FR-013**: Rich content MUST keep feeding all current consumers equivalently: on-screen rendering, list-card descriptions (first paragraph), book and recipe PDFs, and full-text search.
- **FR-014**: There is NO automatic migration of content stored in the previous per-block representation. On first start after the update, if the library contains old-format content, the application MUST inform the user (in Spanish) that the library predates the new format and MUST offer to reset it so the legacy books can be re-imported; it MUST NOT silently display or corrupt old-format content.
- **FR-015**: Library backup archives produced before this change MUST be rejected on import with a clear Spanish message; they MUST never import silently corrupted.

#### Image Fallback on Import

- **FR-016**: During legacy import, a book without a valid image MUST be assigned the first valid image found by searching, in document order, its introduction content and then its chapters' subtrees (chapter introductions, subchapters, recipes).
- **FR-017**: During legacy import, a chapter without a valid image MUST be assigned the first valid image found within its own subtree, in document order.
- **FR-018**: Recipes MUST never receive a fallback image; a recipe without an image remains imageless.
- **FR-019**: When no valid image exists in the searched subtree, the element remains without an image and the import proceeds normally.

#### Display Fixes

- **FR-020**: List cards for items without an image MUST expand the description text area into the space the image would occupy, showing more text before ellipsis truncation; cards with images keep the current layout.
- **FR-021**: In rendered tables — both on screen and in generated PDFs — any cell containing an image MUST align its text to the bottom of the cell, so mixed rows read at a consistent baseline; text-only cells are unaffected.

### Key Entities

- **Rich Content Document**: The new canonical form of an introduction or preparation section — a single rich text (markdown) document supporting headings (hierarchy), paragraphs, emphasis, lists, images with captions, image galleries, and tables; stored per book introduction, chapter introduction, recipe introduction, and recipe preparation.
- **Note**: Short annotation text attached to a book, chapter, or recipe, displayed at the foot of its content; populated from legacy note elements (one or several) and excluded from the rich content body.
- **Legacy Document (v2)**: A legacy book file whose introductions consist of one ordered content list of typed elements; the only import format accepted going forward.
- **Fallback Image Assignment**: An import-time derived relationship — a book or chapter showing an image inherited from the first image-bearing descendant in document order.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For all three updated sample books, 100% of imported introductions present their elements in exactly the source document order (verifiable element-by-element against the source files).
- **SC-002**: In imported introductions containing multiple titles, 100% render the first title visibly larger/higher-level than the subsequent ones.
- **SC-003**: A user can write a complete multi-paragraph introduction with a subsection title, bold text, a list, and an image in a single editing session without using any per-paragraph control, in under 5 minutes.
- **SC-004**: The editor opens in preview mode 100% of the time; switching preview↔source takes one interaction.
- **SC-005**: After importing the sample books, every book and chapter that has at least one image anywhere in its subtree displays an image; 0 recipes received a fallback image.
- **SC-006**: Imageless cards display at least double the description lines they do today (with truncation still applying at the limit), and cards with images are pixel-equivalent to today.
- **SC-007**: In tables mixing image and text cells, the text of every image-bearing cell in a row renders at the cell's bottom edge (uniform baseline across the row).
- **SC-008**: Opening the updated application over an old-format library always produces the informative reset offer (never a crash or scrambled content), and after reset plus re-import of the three sample books the library is fully usable.
- **SC-009**: Full-text search returns at least the same matches for the sample books as before the storage change.

## Assumptions

- **Only schema v2 is supported for legacy import**: the updated sample books are the reference corpus; the old grouped format is rejected, not converted (the corrected files already exist).
- **Heading mapping**: clarified — first title → level 2, subsequent titles → level 3 (a single sublevel; the legacy data does not distinguish deeper levels within one introduction).
- **Markdown is the storage format** for rich content documents, since it natively covers the required formatting (headings, bold, lists, tables, images) and the user explicitly framed the collapsed document as markdown; image references inside content continue to point at the application's image store.
- **Image galleries and captions** are representable within the document (consecutive images render as a gallery/grid; captions accompany images); exact markup conventions are a design decision.
- **No data migration**: the pre-change library is replaceable (its content came from the legacy books, which re-import cleanly under the corrected schema); recipe ingredients remain structured as they are today (groups and items are not part of the rich document).
- **Notes placement**: book/chapter notes display at the foot of the introduction content, mirroring the existing recipe-note style.
- **The block-based per-section editor is removed entirely**, including the "additional presentation content" expansion in book/chapter forms; the description field and rich content editing merge into the single-document editor.
- **PDF output adapts** to render documents with the same visual capabilities as today (headings, images, galleries, tables, and bottom-aligned image-cell text per FR-021), at equal or better fidelity.
- **Legacy file naming**: the updated sample books use new file names (snake_case); import accepts any `.json` file conforming to schema v2 regardless of name.
